# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/eclass/myspell.eclass,v 1.8 2011/12/27 17:55:12 fauli Exp $

# Author: Kevin F. Quinn <kevquinn@gentoo.org>
# Packages: app-dicts/myspell-*
# Herd: app-dicts

inherit multilib

EXPORT_FUNCTIONS src_install pkg_preinst pkg_postinst

IUSE=""

SLOT="0"

# tar, gzip, bzip2 are included in the base profile, but not unzip
DEPEND="app-arch/unzip"

# Dictionaries don't have any runtime dependencies
# Myspell dictionaries can be used by hunspell, openoffice and others
RDEPEND=""

# The destination directory for myspell dictionaries
MYSPELL_DICTBASE="/usr/share/myspell"

# Legacy variable for dictionaries installed before eselect-oodict existed
# so has to remain for binpkg support.  This variable is unmaintained -
# if you have a problem with it, emerge app-admin/eselect-oodict.
# The location for openoffice softlinks
MYSPELL_OOOBASE="/usr/lib/openoffice/share/dict/ooo"


# set array "fields" to the elements of $1, separated by $2.
# This saves having to muck about with IFS all over the place.
set_fields() {
	local old_IFS
	old_IFS="${IFS}"
	IFS=$2
	fields=($1)
	IFS="${old_IFS}"
}

# language is the second element of the ebuild name
# myspell-<lang>-<version>
get_myspell_lang() {
	local fields
	set_fields "${P}" "-"
	echo ${fields[1]}
}

get_myspell_suffixes() {
	case $1 in
		DICT) echo ".aff .dic" ;;
		HYPH) echo ".dic" ;;
		THES) echo ".dat .idx" ;;
	esac
}

# OOo dictionary files are held on the mirrors, rather than
# being fetched direct from the OOo site as upstream doesn't
# change the name when they rebuild the dictionaries.
# <lang>-<country>.zip becomes myspell-<lang>-<country>-version.zip
get_myspell_ooo_uri() {
	local files fields newfile filestem srcfile dict uris
	files=()
	uris=""
	for dict in \
			"${MYSPELL_SPELLING_DICTIONARIES[@]}" \
			"${MYSPELL_HYPHENATION_DICTIONARIES[@]}" \
			"${MYSPELL_THESAURUS_DICTIONARIES[@]}"; do
		set_fields "${dict}" ","
		newfile=${fields[4]// }
		for file in "${files[@]}"; do
			[[ ${file} == ${newfile} ]] && continue 2
		done
		filestem=${newfile/.zip}
		files=("${files[@]}" "${newfile}")
		srcfile="myspell-${filestem}-${PV}.zip"
		[[ -z ${uris} ]] &&
			uris="mirror://gentoo/${srcfile}" ||
			uris="${uris} mirror://gentoo/${srcfile}"
	done
	echo "${uris}"
}


[[ -z ${SRC_URI} ]] && SRC_URI=$(get_myspell_ooo_uri)

# Format of dictionary.lst files (from OOo standard
# dictionary.lst file):
#
# List of All Dictionaries to be Loaded by OpenOffice
# ---------------------------------------------------
# Each Entry in the list have the following space delimited fields
#
# Field 0: Entry Type "DICT" - spellchecking dictionary
#                     "HYPH" - hyphenation dictionary
#                     "THES" - thesaurus files
#
# Field 1: Language code from Locale "en" or "de" or "pt" ...
#
# Field 2: Country Code from Locale "US" or "GB" or "PT"
#
# Field 3: Root name of file(s) "en_US" or "hyph_de" or "th_en_US"
#          (do not add extensions to the name)

# Format of MYSPELL_[SPELLING|HYPHENATION|THESAURUS]_DICTIONARIES:
#
# Field 0: Language code
# Field 1: Country code
# Field 2: Root name of dictionary files
# Field 3: Description
# Field 4: Archive filename
#
# This format is from the available.lst, hyphavail.lst and
# thesavail.lst files on the openoffice.org repository.

myspell_src_install() {
	local filen fields entry dictlst
	cd "${WORKDIR}"
	# Install the dictionary, hyphenation and thesaurus files.
	# Create dictionary.lst.<lang> file containing the parts of
	# OOo's dictionary.lst file for this language, indicating
	# which dictionaries are relevant for each country variant
	# of the language.
	insinto ${MYSPELL_DICTBASE}
	dictlst="dictionary.lst.$(get_myspell_lang)"
	echo "# Autogenerated by ${CATEGORY}/${P}" > ${dictlst}
	for entry in "${MYSPELL_SPELLING_DICTIONARIES[@]}"; do
		set_fields "${entry}" ","
		echo "DICT ${fields[0]} ${fields[1]} ${fields[2]}" >> ${dictlst}
		doins ${fields[2]}.aff || die "Missing ${fields[2]}.aff"
		doins ${fields[2]}.dic || die "Missing ${fields[2]}.dic"
	done
	for entry in "${MYSPELL_HYPHENATION_DICTIONARIES[@]}"; do
		set_fields "${entry}" ","
		echo "HYPH ${fields[0]} ${fields[1]} ${fields[2]}" >> ${dictlst}
		doins ${fields[2]}.dic || die "Missing ${fields[2]}.dic"
	done
	for entry in "${MYSPELL_THESAURUS_DICTIONARIES[@]}"; do
		set_fields "${entry}" ","
		echo "THES ${fields[0]} ${fields[1]} ${fields[2]}" >> ${dictlst}
		doins ${fields[2]}.dat || die "Missing ${fields[2]}.dat"
		doins ${fields[2]}.idx || die "Missing ${fields[2]}.idx"
	done
	doins ${dictlst} || die "Failed to install ${dictlst}"
	# Install any txt files (usually README.txt) as documentation
	for filen in *.txt; do
		[[ -s ${filen} ]] && dodoc ${filen}
	done
}


# Add entries in dictionary.lst.<lang> to OOo dictionary.lst
# and create softlinks indicated by dictionary.lst.<lang>
myspell_pkg_postinst() {
	# Update for known applications
	if has_version ">=app-admin/eselect-oodict-20060706"; then
		if has_version app-office/openoffice; then
			eselect oodict set myspell-$(get_myspell_lang)
		fi
		if has_version app-office/openoffice-bin; then
			# On AMD64, openoffice-bin is 32-bit so force ABI
			has_multilib_profile && ABI=x86
			eselect oodict set myspell-$(get_myspell_lang) --libdir $(get_libdir)
		fi
		return
	fi
	if has_version app-admin/eselect-oodict; then
		eselect oodict set myspell-$(get_myspell_lang)
		return
	fi

	# Legacy code for dictionaries installed before eselect-oodict existed
	# so has to remain for binpkg support.  This code is unmaintained -
	# if you have a problem with it, emerge app-admin/eselect-oodict.
	[[ -d ${MYSPELL_OOOBASE} ]] || return
	# This stuff is here, not in src_install, as the softlinks are
	# deliberately _not_ listed in the package database.
	local dictlst entry fields prefix suffix suffixes filen
	# Note; can only reach this point if ${MYSPELL_DICTBASE}/${dictlst}
	# was successfully installed
	dictlst="dictionary.lst.$(get_myspell_lang)"
	while read entry; do
		fields=(${entry})
		[[ ${fields[0]:0:1} == "#" ]] && continue
		[[ -f ${MYSPELL_OOOBASE}/dictionary.lst ]] || \
			touch ${MYSPELL_OOOBASE}/dictionary.lst
		grep "^${fields[0]} ${fields[1]} ${fields[2]} " \
			${MYSPELL_OOOBASE}/dictionary.lst > /dev/null 2>&1 ||
				echo "${entry}" >> ${MYSPELL_OOOBASE}/dictionary.lst
		for suffix in $(get_myspell_suffixes ${fields[0]}); do
			filen="${fields[3]}${suffix}"
			[[ -h ${MYSPELL_OOOBASE}/${filen} ]] &&
				rm -f ${MYSPELL_OOOBASE}/${filen}
			[[ ! -f ${MYSPELL_OOOBASE}/${filen} ]] &&
				ln -s ${MYSPELL_DICTBASE}/${filen} \
					${MYSPELL_OOOBASE}/${filen}
		done
	done < ${MYSPELL_DICTBASE}/${dictlst}
}


# Remove softlinks and entries in dictionary.lst - uses
# dictionary.<lang>.lst from /usr/share/myspell
# Done in preinst (prerm happens after postinst, which overwrites
# the dictionary.<lang>.lst file)
myspell_pkg_preinst() {
	# Update for known applications
	if has_version ">=app-admin/eselect-oodict-20060706"; then
		if has_version app-office/openoffice; then
			# When building from source, the default library path is correct
			eselect oodict unset myspell-$(get_myspell_lang)
		fi
		if has_version app-office/openoffice-bin; then
			# On AMD64, openoffice-bin is 32-bit, so get 32-bit library directory
			has_multilib_profile && ABI=x86
			eselect oodict unset myspell-$(get_myspell_lang) --libdir $(get_libdir)
		fi
		eselect oodict unset myspell-$(get_myspell_lang) --libdir $(get_libdir)
		return
	fi
	# Previous versions of eselect-oodict didn't cater for -bin on amd64
	if has_version app-admin/eselect-oodict; then
		eselect oodict unset myspell-$(get_myspell_lang)
		return
	fi

	# Legacy code for dictionaries installed before eselect-oodict existed
	# Don't delete this; needed for uninstalls and binpkg support.
	# This code is unmaintained - if you have a problem with it,
	# emerge app-admin/eselect-oodict.
	local filen dictlst entry fields removeentry suffix
	dictlst="dictionary.lst.$(get_myspell_lang)"
	[[ -d ${MYSPELL_OOOBASE} ]] || return
	[[ -f ${MYSPELL_DICTBASE}/${dictlst} ]] || return
	while read entry; do
		fields=(${entry})
		[[ ${fields[0]:0:1} == "#" ]] && continue
		[[ ${fields[3]} == "" ]] && continue
		# Remove entry from dictionary.lst
		sed -i -e "/^${fields[0]} ${fields[1]} ${fields[2]} ${fields[3]}$/ { d }" \
			${MYSPELL_OOOBASE}/dictionary.lst
		# See if any other entries in dictionary.lst match the current
		# dictionary type and filename
		grep "^${fields[0]} .* ${fields[3]}$" ${MYSPELL_OOOBASE}/dictionary.lst \
			2>&1 > /dev/null && continue
		# If no other entries match, remove relevant symlinks
		for suffix in $(get_myspell_suffixes ${fields[0]}); do
			filen="${fields[3]}${suffix}"
			ewarn "Removing entry ${MYSPELL_OOOBASE}/${filen}"
			[[ -h ${MYSPELL_OOOBASE}/${filen} ]] &&
				rm -f ${MYSPELL_OOOBASE}/${filen}
		done
	done < ${MYSPELL_DICTBASE}/${dictlst}
}
