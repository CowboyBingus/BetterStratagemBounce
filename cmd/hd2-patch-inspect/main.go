package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/xypwn/filediver/hashes"
	"github.com/xypwn/filediver/stingray"
)

type hashInfo struct {
	Hex  string `json:"hex"`
	Name string `json:"name,omitempty"`
}

type diffRange struct {
	Offset     int    `json:"offset"`
	Length     int    `json:"length"`
	VanillaHex string `json:"vanilla_hex"`
	PatchHex   string `json:"patch_hex"`
}

type comparison struct {
	VanillaExists   bool        `json:"vanilla_exists"`
	VanillaSize     int         `json:"vanilla_size,omitempty"`
	VanillaSHA256   string      `json:"vanilla_sha256,omitempty"`
	Equal           bool        `json:"equal"`
	SizeDelta       int         `json:"size_delta"`
	ChangedBytes    int         `json:"changed_bytes"`
	CommonPrefix    int         `json:"common_prefix"`
	CommonSuffix    int         `json:"common_suffix"`
	RangesTruncated bool        `json:"ranges_truncated,omitempty"`
	DiffRanges      []diffRange `json:"diff_ranges,omitempty"`
}

type dataPart struct {
	Kind       string      `json:"kind"`
	Offset     uint64      `json:"offset"`
	Size       uint32      `json:"size"`
	SHA256     string      `json:"sha256,omitempty"`
	Extracted  string      `json:"extracted,omitempty"`
	Comparison *comparison `json:"comparison,omitempty"`
}

type resourceRecord struct {
	Index         uint32     `json:"index"`
	Name          hashInfo   `json:"name"`
	Type          hashInfo   `json:"type"`
	MainAlignment uint32     `json:"main_alignment"`
	GPUAlignment  uint32     `json:"gpu_alignment"`
	Parts         []dataPart `json:"parts"`
}

type typeRecord struct {
	Name          hashInfo `json:"name"`
	Count         uint32   `json:"count"`
	MainAlignment uint32   `json:"main_alignment"`
	GPUAlignment  uint32   `json:"gpu_alignment"`
}

type report struct {
	PatchPath  string           `json:"patch_path"`
	ArchiveID  hashInfo         `json:"archive_id"`
	NumTypes   uint32           `json:"num_types"`
	NumFiles   uint32           `json:"num_files"`
	Types      []typeRecord     `json:"types"`
	Resources  []resourceRecord `json:"resources"`
	GameDir    string           `json:"game_dir,omitempty"`
	StaticOnly bool             `json:"static_only"`
	Notes      []string         `json:"notes"`
}

func knownHashes() map[uint64]string {
	result := make(map[uint64]string)
	for _, source := range []string{hashes.Hashes, hashes.ThinHashes, hashes.DLTypeNames} {
		for _, name := range hashes.ParseHashes(source) {
			h := stingray.Sum(name).Value
			if _, exists := result[h]; !exists {
				result[h] = name
			}
		}
	}
	return result
}

func describeHash(hash stingray.Hash, known map[uint64]string) hashInfo {
	return hashInfo{Hex: hash.String(), Name: known[hash.Value]}
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return strings.ToUpper(hex.EncodeToString(sum[:]))
}

func commonPrefix(a, b []byte) int {
	limit := min(len(a), len(b))
	for i := 0; i < limit; i++ {
		if a[i] != b[i] {
			return i
		}
	}
	return limit
}

func commonSuffix(a, b []byte, prefix int) int {
	limit := min(len(a), len(b)) - prefix
	for i := 0; i < limit; i++ {
		if a[len(a)-1-i] != b[len(b)-1-i] {
			return i
		}
	}
	return limit
}

func makeComparison(vanilla, patched []byte, vanillaExists bool) comparison {
	result := comparison{
		VanillaExists: vanillaExists,
		VanillaSize:   len(vanilla),
		SizeDelta:     len(patched) - len(vanilla),
	}
	if !vanillaExists {
		result.ChangedBytes = len(patched)
		return result
	}
	result.VanillaSHA256 = sha256Hex(vanilla)
	result.Equal = len(vanilla) == len(patched) && string(vanilla) == string(patched)
	result.CommonPrefix = commonPrefix(vanilla, patched)
	result.CommonSuffix = commonSuffix(vanilla, patched, result.CommonPrefix)

	const maxRanges = 256
	const maxBytesPerRange = 128
	limit := min(len(vanilla), len(patched))
	for offset := 0; offset < limit; {
		if vanilla[offset] == patched[offset] {
			offset++
			continue
		}
		start := offset
		for offset < limit && vanilla[offset] != patched[offset] {
			offset++
		}
		result.ChangedBytes += offset - start
		if len(result.DiffRanges) >= maxRanges {
			result.RangesTruncated = true
			continue
		}
		end := min(offset, start+maxBytesPerRange)
		result.DiffRanges = append(result.DiffRanges, diffRange{
			Offset:     start,
			Length:     offset - start,
			VanillaHex: hex.EncodeToString(vanilla[start:end]),
			PatchHex:   hex.EncodeToString(patched[start:end]),
		})
	}
	if len(vanilla) != len(patched) {
		result.ChangedBytes += max(len(vanilla), len(patched)) - limit
	}
	return result
}

func readPart(path string, offset uint64, size uint32) ([]byte, error) {
	if size == 0 {
		return nil, nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	data := make([]byte, size)
	if _, err := f.ReadAt(data, int64(offset)); err != nil && !errors.Is(err, io.EOF) {
		return nil, err
	}
	return data, nil
}

func archiveIDFromPath(path string) (string, error) {
	base := filepath.Base(path)
	if before, _, ok := strings.Cut(base, ".patch_"); ok {
		base = before
	}
	if len(base) != 16 {
		return "", fmt.Errorf("cannot derive 16-digit archive hash from %q", filepath.Base(path))
	}
	if _, err := stingray.ParseHash(base); err != nil {
		return "", err
	}
	return base, nil
}

func safeResourceStem(file stingray.FileData) string {
	return fmt.Sprintf("%03d_%016x.%016x", file.Index, file.ID.Name.Value, file.ID.Type.Value)
}

func writeExtract(dir, stem, suffix string, data []byte) (string, error) {
	if dir == "" || len(data) == 0 {
		return "", nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	path := filepath.Join(dir, stem+suffix)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return "", err
	}
	abs, _ := filepath.Abs(path)
	return abs, nil
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func main() {
	patchPath := flag.String("patch", "", "Stingray .patch_N main archive (required)")
	gameDir := flag.String("game-dir", `C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2`, "optional vanilla Helldivers 2 directory")
	outPath := flag.String("out", "artifacts/stratagem/patch-inspection-report.json", "JSON report path")
	extractDir := flag.String("extract-dir", "", "directory for raw patch and vanilla payloads; empty disables extraction")
	flag.Parse()
	if *patchPath == "" {
		fail("-patch is required")
	}

	absPatch, err := filepath.Abs(*patchPath)
	if err != nil {
		fail("resolve patch path: %v", err)
	}
	archiveIDText, err := archiveIDFromPath(absPatch)
	if err != nil {
		fail("archive ID: %v", err)
	}
	mainFile, err := os.Open(absPatch)
	if err != nil {
		fail("open patch: %v", err)
	}
	archive, err := stingray.LoadArchive(archiveIDText, mainFile)
	mainFile.Close()
	if err != nil {
		fail("parse patch archive: %v", err)
	}

	var vanilla *stingray.DataDir
	if *gameDir != "" {
		vanilla, err = stingray.OpenDataDir(context.Background(), filepath.Join(*gameDir, "data"), nil)
		if err != nil {
			fail("open vanilla game data: %v", err)
		}
	}
	known := knownHashes()
	result := report{
		PatchPath:  absPatch,
		ArchiveID:  describeHash(archive.ID, known),
		NumTypes:   archive.Header.NumTypes,
		NumFiles:   archive.Header.NumFiles,
		GameDir:    *gameDir,
		StaticOnly: true,
		Notes: []string{
			"The patch archive was parsed and compared without executing or installing it.",
			"Known names are exact Murmur64 matches from Filediver's FOSS hash dictionaries.",
			"A resource override changes game data; its presence does not imply executable or runtime-memory patching.",
		},
	}
	for _, typ := range archive.Types {
		result.Types = append(result.Types, typeRecord{
			Name:          describeHash(typ.Name, known),
			Count:         typ.Count,
			MainAlignment: typ.MainAlignment,
			GPUAlignment:  typ.GPUAlignment,
		})
	}

	partNames := []string{"main", "stream", "gpu_resources"}
	partPaths := []string{absPatch, absPatch + ".stream", absPatch + ".gpu_resources"}
	for _, file := range archive.Files {
		record := resourceRecord{
			Index:         file.Index,
			Name:          describeHash(file.ID.Name, known),
			Type:          describeHash(file.ID.Type, known),
			MainAlignment: file.MainAlignment,
			GPUAlignment:  file.GPUAlignment,
		}
		for dataType := stingray.DataMain; dataType < stingray.NumDataType; dataType++ {
			size := file.Sizes[dataType]
			part := dataPart{Kind: partNames[dataType], Offset: file.Offsets[dataType], Size: size}
			if size == 0 {
				record.Parts = append(record.Parts, part)
				continue
			}
			patched, err := readPart(partPaths[dataType], file.Offsets[dataType], size)
			if err != nil {
				fail("read patch resource %s %s: %v", file.ID.Name, part.Kind, err)
			}
			part.SHA256 = sha256Hex(patched)
			stem := safeResourceStem(file)
			part.Extracted, err = writeExtract(*extractDir, stem, ".patch."+part.Kind, patched)
			if err != nil {
				fail("extract patch resource: %v", err)
			}
			if vanilla != nil {
				vanillaData, readErr := vanilla.Read(file.ID, dataType)
				exists := readErr == nil
				if readErr != nil && !errors.Is(readErr, stingray.ErrFileNotExist) && !errors.Is(readErr, stingray.ErrFileDataTypeNotExist) {
					fail("read vanilla resource %s %s: %v", file.ID.Name, part.Kind, readErr)
				}
				cmp := makeComparison(vanillaData, patched, exists)
				part.Comparison = &cmp
				if exists {
					if _, err := writeExtract(*extractDir, stem, ".vanilla."+part.Kind, vanillaData); err != nil {
						fail("extract vanilla resource: %v", err)
					}
				}
			}
			record.Parts = append(record.Parts, part)
		}
		result.Resources = append(result.Resources, record)
	}

	encoded, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fail("encode report: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(*outPath), 0o755); err != nil {
		fail("create report directory: %v", err)
	}
	if err := os.WriteFile(*outPath, append(encoded, '\n'), 0o644); err != nil {
		fail("write report: %v", err)
	}

	fmt.Printf("archive %s: %d resources across %d types\n", archive.ID, len(result.Resources), len(result.Types))
	for _, resource := range result.Resources {
		name := resource.Name.Hex
		if resource.Name.Name != "" {
			name = resource.Name.Name
		}
		typ := resource.Type.Hex
		if resource.Type.Name != "" {
			typ = resource.Type.Name
		}
		for _, part := range resource.Parts {
			if part.Size == 0 {
				continue
			}
			status := "not compared"
			if part.Comparison != nil {
				if !part.Comparison.VanillaExists {
					status = "new resource"
				} else if part.Comparison.Equal {
					status = "identical"
				} else {
					status = fmt.Sprintf("changed=%d size_delta=%+d prefix=0x%x suffix=0x%x", part.Comparison.ChangedBytes, part.Comparison.SizeDelta, part.Comparison.CommonPrefix, part.Comparison.CommonSuffix)
				}
			}
			fmt.Printf("  [%d] %s.%s %s %d bytes: %s\n", resource.Index, name, typ, part.Kind, part.Size, status)
		}
	}
	fmt.Printf("report: %s\n", *outPath)
}
