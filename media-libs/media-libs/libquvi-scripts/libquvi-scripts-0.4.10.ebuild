# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/media-libs/libquvi-scripts/libquvi-scripts-0.4.10.ebuild,v 1.10 2013/02/02 22:50:26 ago Exp $

EAPI=5

DESCRIPTION="Embedded lua scripts for libquvi"
HOMEPAGE="http://quvi.sourceforge.net/"
SRC_URI="mirror://sourceforge/quvi/${PV:0:3}/${P}.tar.xz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~alpha amd64 ~arm hppa ~ia64 ppc ppc64 ~sparc x86"
IUSE="offensive"

DEPEND="app-arch/xz-utils"

# tests fetch data from live websites, so it's rather normal that they
# will fail
RESTRICT="test"

src_configure() {
	econf \
		--with-manual \
		$(use_with offensive nsfw)
}
