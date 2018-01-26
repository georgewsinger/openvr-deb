installDebHelpers() {
  sudo apt install  \
    autoconf        \
    automake        \
    autotools-dev   \
    debmake         \
    dh-make         \
    devscripts      \
    fakeroot        \
    file            \
    gnupg           \
    lintian         \
    patch           \
    patchutils      \
    pbuilder        \
    quilt           \
    xutils-dev      \

    # probably included by default:
    build-essential \
    debhelper       \ # provides dh_* commands
    dh-make         \
    debmake
}

exportDebianEnvironmentVariables() {
  if [[ -z "${DEBEMAIL}" ]]; then
    echo 'DEBEMAIL="george.w.singer@gmail.com"' >> ~/.bashrc
    echo 'export DEBEMAIL'          >> ~/.bashrc
  fi

  if [[ -z "${DEBFULLNAME}" ]]; then
    echo 'DEBFULLNAME="George Singer"'          >> ~/.bashrc
    echo 'export DEBFULLNAME'                      >> ~/.bashrc
  fi

  . ~/.bashrc
}


generateFreshSourceV1_0_11() {
  git clone https://github.com/ValveSoftware/openvr openvr-1.0.11
  cd openvr-1.0.11
  # TODO: Strip `openvr-1.0.11.tar.gz` of unneeded cruft
  git checkout tags/v1.0.11
  cd ..
}

generateFreshUpstreamTarV1_0_11() {
    git clone https://github.com/ValveSoftware/openvr tmp-openvr-1.0.11
    cd tmp-openvr-1.0.11
    git checkout tags/v1.0.11
    cd ..

    # TODO: Strip `openvr-1.0.11.tar.gz` of unneeded cruft

    tar -cvzf openvr-1.0.11.tar.gz tmp-openvr-1.0.11 --exclude-vcs
    sudo rm -r tmp-openvr-1.0.11
}

dh_make_openvr() {
  cd openvr-1.0.11
  dh_make -f ../openvr-1.0.11.tar.gz # I believe we want option `s`, a single binary package that will make one `openvr*.deb`

  cd ..

  # VERIFY: (i)  ./openvr-1.0.11/debian/* exists
  #         (ii) ./openvr_1.0.11.orig.tar.gz exists
}

modifyDebianRulesFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/rules ./openvr-1.0.11/debian/rules
}

modifyDebianControlFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/control ./openvr-1.0.11/debian/control
}

modifyDebianCopyrightFile() {
    # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
    cp ./resources/copyright ./openvr-1.0.11/debian/copyright
}

modifyDebianChangelogFile() {
    # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
    cp ./resources/changelog ./openvr-1.0.11/debian/changelog
}

deleteUnneededDebianFiles() {
    rm openvr-1.0.11/debian/README.Debian     # Not needed for now
    rm openvr-1.0.11/debian/README.source     # Not needed for now
    rm openvr-1.0.11/debian/openvr-docs.docs  # This references the above 2 files
}

buildPackage() {
  # PREREQUISITES:
  # sudo apt-get install build-depends \ 
  #                      < Build-Depends entries > 
  #                      < Build-Depends-indep entries > 

  cd openvr-1.0.11
  dpkg-buildpackage -us -uc

  # This will:
  # 1. Clean the source tree (debian/rules clean)
  # 2. Build the source package (dpkg-source -b)
  # 3. Build the program (debian/rules build)
  # 4. Build binary packages (fakeroot debian/rules binary)
  # 5. TODO: Make the .dsc file (Verify)
  # 6. TODO: Make the .changes file, using dpkg-genchanges (Verify)

  debsign # Must be ran within openvr-1.0.11 since it accesses ./debian/changelog.
          # If you receive trouble with debsign, try putting
          # DEBSIGN_KEYID=Your_GPG_keyID 
          # in ~/.devscripts

  # To verify the source package was generated, run `cd ~/openvr-deb` and verify the following exist:
  # 1. openvr_1.0.11.orig.tar.gz
  # 2. openvr_1.0.11-1.dsc: Generated from debian/control; used by dpkg-source; needs debsigned
  # 3. openvr_1.0.11-1.debian.tar.gz: Contains debian/* with patches in debian/patches
  # 4. openvr_1.0.11-1_amd64.deb
  # 5. openvr_1.0.11-1_amd64.changes: Needs debsigned.
  # With (1)-(3), you can run `dpkg-source -x gentoo_0.9.12-1.dsc` to completely recreate the package from scratch.

  # FOOTNOTE 1: 
  # Alternative to `dpkg-buildpackage -us -uc`:
  # First place the following in ~/.devscripts:
  # ```
  # DEBUILD_DPKG_BUILDPACKAGE_OPTS="-us -uc -I -i"
  # DEBUILD_LINTIAN_OPTS="-i -I --show-overrides"
  # ```
  # Then you can run `debuild` (as well as `debuild clean`), which wraps `dpkg-buildpackage -us -uc`.

  cd ..
}

verifyPackageInstallation() {
  cd openvr-1.0.11/debian
  ls -tlra | grep change-                # verify this is empty; if it's not, it means "files were changed by accident or the build script modified the upstream source"

  cd ../..
  sudo debi openvr_1.0.11-1_amd64.changes # tests whether your package installs w/o problems

  # lintian only required if you build mannually w/dpkg-buildpackage as opposed to debuild (which wraps lintian); lintian codes:
  #   E: Error
  #   W: Warning
  #   I: Info
  #   N: Note
  #   O: Overriden (you can set overrides via `lintian-overrides` file
  lintian -i -I --show-overrides openvr_1.0.11-1_amd64.changes

  # TRIAGED since we're not using "maintainer scripts"
  # 
  # sudo dpkg -r openvr
  # sudo dpkg -P openvr
  # sudo dpkg -i openvr_1.0.11-revision_amd64.deb

  # TRIAGED: version conflicts
  # "If this is your first package, you should create dummy packages with different versions to test your package in advance to prevent future problems."

  # TRIAGED: upgrades
  # "Bear in mind that if your package has previously been released in Debian, people will often be upgrading to your package from the version that was in the last Debian release. Remember to test upgrades from that version too."

  # TRIAGED: downgrades
  # "Although downgrading is not officially supported, supporting it is a friendly gesture."
}

uploadPackage() {
   # http://packaging.ubuntu.com/html/getting-set-up.html
   # http://packaging.ubuntu.com/html/packaging-new-software.html
   # https://www.debian.org/doc/manuals/maint-guide/upload.en.html
   echo "TODO"
}

cleanRoot() {
    sudo rm openvr_1.0.11-1_amd64.buildinfo
    sudo rm openvr_1.0.11-1_amd64.changes
    sudo rm openvr_1.0.11-1_amd64.deb
    sudo rm openvr_1.0.11-1_amd64.tar.xz
    sudo rm openvr_1.0.11-1.dsc
    sudo rm openvr_1.0.11.orig.tar.gz
    sudo rm openvr_1.0.11.tar.gz
    sudo rm openvr_1.0.11-1.debian.tar.xz
    sudo rm openvr-1.0.11.tar.gz
    sudo rm -r openvr-1.0.11
}

generateOpenVRDebianPackage() {
  #installDebHelpers
  #exportDebianEnvironmentVariables

  generateFreshSourceV1_0_11
  generateFreshUpstreamTarV1_0_11

  dh_make_openvr

  modifyDebianRulesFile
  modifyDebianControlFile
  modifyDebianCopyrightFile
  modifyDebianChangelogFile
  deleteUnneededDebianFiles

  buildPackage

  #verifyPackageInstallation

  # uploadPackage
}

# Questions
#  1. How to strip binaries to reduce package size?
#  2. Does `CMakeLists.txt` need to be modified (in a similar way that all `Makefiles` need to be modified, as below)?

# Resources #
# 1. #debian-mentors on IRC
# 2. How to use Quilt:
#     - https://www.debian.org/doc/manuals/maint-guide/modify.en.html#quiltrc
#     - example:
#       $ dquilt new foo2.patch
#       $ dquilt add Makefile
#       $ sed -i -e 's/-lfoo/-lfoo2/g' Makefile
#       $ dquilt refresh
#       $ dquilt header -e
#       ... describe patch
# 3. How to sanitize a project's Makefile for Debian:
#     - remove all `local` references to follow the FHS
#     - use $(DESTDIR), which is equal to `<package-src>/debian/package/`
#        - EX: Change all, i.e., `/usr/local/bin` to `$(DESTDIR)/usr/bin`
#     - also insert `install -d <dirname>` to ensure directories are created in $(DESTDIR)