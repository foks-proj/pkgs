package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

type runner struct {
	keyFingerprint string
}

type osType string
type osCodename string
type osArch string

var allArches = []osArch{"arm64", "amd64", "all"}

func (r *runner) linkTo(dir string, ar osArch) error {
	cwd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current working directory: %w", err)
	}
	defer func() {
		if err := os.Chdir(cwd); err != nil {
			fmt.Printf("Failed to change directory back to %s: %v\n", cwd, err)
		}
	}()
	if err := os.Chdir(dir); err != nil {
		return fmt.Errorf("failed to change directory to %s: %w", dir, err)
	}

	debs, err := filepath.Glob(filepath.Join("..", "..", "..", "..", "pool", "main", "f", "*_"+string(ar)+".deb"))
	if err != nil {
		return fmt.Errorf("failed to glob for .deb files: %w", err)
	}
	for _, deb := range debs {
		base := filepath.Base(deb)
		if err := os.Symlink(deb, base); err != nil {
			if os.IsExist(err) {
				fmt.Printf("Warning: symlink %s already exists, skipping\n", base)
				continue
			}
			return fmt.Errorf("failed to create symlink for %s: %w", base, err)
		}
		fmt.Printf("Created symlink: %s -> %s\n", base, deb)
	}
	return nil
}

func (r *runner) doCodenameArch(osType osType, codename osCodename, arch osArch) error {

	dir := filepath.Join("dists", string(codename), "main", "binary-"+string(arch))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}
	err := r.linkTo(dir, arch)
	if err != nil {
		return fmt.Errorf("failed to link to directory %s for arch %s: %w", dir, arch, err)
	}

	// This function should implement the logic to process a specific OS type,
	// codename, and architecture. The implementation is not provided in the original code.
	// For now, we will return an error indicating that this function is not implemented.
	return fmt.Errorf("doCodenameArch for OS %s, codename %s, arch %s is not implemented", osType, codename, arch)
}

func (r *runner) doCodename(osType osType, codename osCodename) error {

	for _, arch := range allArches {
		if err := r.doCodenameArch(osType, codename, arch); err != nil {
			return fmt.Errorf("failed to process codename %s for OS %s with arch %s: %w", codename, osType, arch, err)
		}
	}
	return errors.New("not implemented")
}

func (r *runner) doOS(osType osType, codenames []osCodename) error {
	cwd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current working directory: %w", err)
	}
	defer func() {
		if err := os.Chdir(cwd); err != nil {
			fmt.Printf("Failed to change directory back to %s: %v\n", cwd, err)
		}
	}()
	dir := filepath.Join("public", "stable", string(osType))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}
	if err := os.Chdir(dir); err != nil {
		return fmt.Errorf("failed to change directory to %s: %w", dir, err)
	}
	for _, codename := range codenames {
		err := r.doCodename(osType, codename)
		if err != nil {
			return fmt.Errorf("failed to process codename %s for OS %s: %w", codename, osType, err)
		}
	}
	return nil
}

func (r *runner) run(cmd *cobra.Command, args []string) error {
	err := r.doOS("debian", []osCodename{"bookworm", "bullseye", "buster", "trixie"})
	if err != nil {
		return err
	}
	err = r.doOS("ubuntu", []osCodename{"plucky", "oracular", "noble", "jammy", "focal", "bionic", "xenial"})
	if err != nil {
		return err
	}
	return nil
}

func (r *runner) cmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mkdeb",
		Short: "mkdeb is a tool for creating a Debian package tree",
		Long:  "mkdeb is a tool for creating Debian package tree from .deb files",
		RunE: func(cmd *cobra.Command, args []string) error {
			return r.run(cmd, args)
		},
	}
	cmd.Flags().StringVarP(&r.keyFingerprint, "key-fingerprint", "k", "", "GPG key fingerprint to sign the package")
	cmd.MarkFlagRequired("key-fingerprint")

	return cmd
}

func main() {
	r := &runner{}
	cmd := r.cmd()
	err := cmd.Execute()
	rc := 0
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		rc = -2
	}
	os.Exit(rc)
}
