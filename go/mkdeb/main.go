package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

type runner struct {
	keyFingerprint string
}

type osType string
type osCodename string

func (r *runner) doOS(osType osType, codenames []osCodename) error {
	return errors.New("not implemented")
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
