package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/xypwn/filediver/stingray"
)

func main() {
	gameDir := flag.String("game-dir", `C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2`, "Helldivers 2 directory")
	nameText := flag.String("name", "", "resource name hash")
	typeText := flag.String("type", "", "resource type hash or known type name")
	partText := flag.String("part", "main", "main, stream, or gpu_resources")
	output := flag.String("out", "", "output file")
	flag.Parse()

	if *nameText == "" || *typeText == "" || *output == "" {
		fail("-name, -type, and -out are required")
	}
	name, err := parseHashOrName(*nameText)
	if err != nil {
		fail("parse name: %v", err)
	}
	typ, err := parseHashOrName(*typeText)
	if err != nil {
		fail("parse type: %v", err)
	}
	part, err := parsePart(*partText)
	if err != nil {
		fail("%v", err)
	}

	dataDir, err := stingray.OpenDataDir(context.Background(), filepath.Join(*gameDir, "data"), nil)
	if err != nil {
		fail("open game data: %v", err)
	}
	data, err := dataDir.Read(stingray.NewFileID(name, typ), part)
	if err != nil {
		fail("read %s.%s %s: %v", name, typ, part, err)
	}
	if err := os.MkdirAll(filepath.Dir(*output), 0o755); err != nil {
		fail("create output directory: %v", err)
	}
	if err := os.WriteFile(*output, data, 0o644); err != nil {
		fail("write output: %v", err)
	}
	sum := sha256.Sum256(data)
	fmt.Printf("extracted %s.%s %s: %d bytes sha256=%s -> %s\n", name, typ, part, len(data), strings.ToUpper(hex.EncodeToString(sum[:])), *output)
}

func parseHashOrName(value string) (stingray.Hash, error) {
	if strings.HasPrefix(value, "0x") || len(value) == 16 {
		return stingray.ParseHash(value)
	}
	return stingray.Sum(value), nil
}

func parsePart(value string) (stingray.DataType, error) {
	switch strings.ToLower(value) {
	case "main":
		return stingray.DataMain, nil
	case "stream":
		return stingray.DataStream, nil
	case "gpu", "gpu_resources":
		return stingray.DataGPU, nil
	default:
		return 0, fmt.Errorf("unknown part %q", value)
	}
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "hd2-resource-extract: "+format+"\n", args...)
	os.Exit(1)
}
