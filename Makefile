### -*-Makefile-*- for GitHub page of GNU Emacs Modified for Windows
##
## Copyright (C) 2014-2017 Vincent Goulet
##
## The code of this Makefile is based on a file created by Remko
## Troncon (http://el-tramo.be/about).
##
## Author: Vincent Goulet
##
## This file is part of GNU Emacs Modified for Windows
## http://github.com/vigou3/emacs-modified-windows

## Set most variables in Makeconf
include ./Makeconf

## Build directory et al.
TMPDIR=${CURDIR}/tmpdir

## Emacs specific info
PREFIX=${TMPDIR}/emacs-bin
EMACS=${PREFIX}/bin/emacs.exe
EMACSBATCH = $(EMACS) -batch -no-site-file -no-init-file

## Inno Setup info
INNOSCRIPT=emacs-modified.iss
INNOSETUP=c:/PROGRA~2/INNOSE~1/iscc.exe
INFOBEFOREFR=InfoBefore-fr.txt
INFOBEFOREEN=InfoBefore-en.txt

## Override of ESS variables
DESTDIR=${PREFIX}/share/
SITELISP=${DESTDIR}/emacs/site-lisp
ETCDIR=${DESTDIR}/emacs/etc
DOCDIR=${DESTDIR}/doc
INFODIR=${DESTDIR}/info

## Base name of extensions
LIBPNG=libpng-${LIBPNGVERSION}-w32-bin
ZLIB=zlib-${ZLIBVERSION}-w32-bin
JPEG=jpeg-${JPEGVERSION}-w32-bin
TIFF=tiff-${TIFFVERSION}-w32-bin
GIFLIB=giflib-${GIFLIBVERSION}-w32-bin
LIBRSVG=librsvg-${LIBRSVGVERSION}-w32-bin
GNUTLS=gnutls-${GNUTLSVERSION}-w32-bin
LIBS=libs

all : get-packages emacs release

get-packages : get-psvn get-libs

emacs : dir libs psvn exe

release : create-release upload publish

.PHONY : emacs dir libs psvn exe release create-release upload publish clean

dir :
	@echo ----- Creating the application in temporary directory...
	if [ -d ${TMPDIR} ]; then rm -rf ${TMPDIR}; fi
	mkdir -p ${PREFIX}
	unzip -q ${ZIPFILE} -d ${PREFIX}
	cp -dpr aspell ${PREFIX}
	cp -p default.el ${SITELISP}/
	sed -e '/^(defconst/s/<DISTVERSION>/${DISTVERSION}/' \
	    version-modified.el.in > ${SITELISP}/version-modified.el
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/version-modified.el
	cp -p framepop.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/framepop.el
	cp -p w32-winprint.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/w32-winprint.el
	cp -p htmlize.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/htmlize.el
	cp -p htmlize-view.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/htmlize-view.el
	cp -p essh.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/essh.el
	cp -p hfyview.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/hfyview.el
	sed -e 's/<VERSION>/${VERSION}/' \
	    -e 's/<EMACSVERSION>/${EMACSVERSION}/' \
	    -e 's/<DISTNAME>/${DISTNAME}/' \
	    ${INNOSCRIPT}.in > ${TMPDIR}/${INNOSCRIPT}
	sed -e 's/<VERSION>/${VERSION}/' \
	    -e 's/<PSVNVERSION>/${PSVNVERSION}/' \
	    -e 's/<LIBPNGVERSION>/${LIBPNGVERSION}/' \
	    -e 's/<ZLIBVERSION>/${ZLIBVERSION}/' \
	    -e 's/<JPEGVERSION>/${JPEGVERSION}/' \
	    -e 's/<TIFFVERSION>/${TIFFVERSION}/' \
	    -e 's/<GIFLIBVERSION>/${GIFLIBVERSION}/' \
	    -e 's/<LIBRSVGVERSION>/${LIBRSVGVERSION}/' \
	    -e 's/<GNUTLSVERSION>/${GNUTLSVERSION}/' \
		    README-Modified.txt.in > ${TMPDIR}/README-Modified.txt
	curl --output site-start.el https://raw.githubusercontent.com/izahn/dotemacs/master/init.el
	cp -p site-start.el NEWS ${TMPDIR}

libs :
	@echo ----- Copying image libraries...
	if [ -d ${LIBS} ]; then rm -rf ${LIBS}; fi
	unzip -j ${LIBPNG}.zip bin/libpng16-16.dll -d ${LIBS}
	unzip -j ${ZLIB}.zip bin/zlib1.dll -d ${LIBS}
	unzip -j ${JPEG}.zip bin/libjpeg-9.dll -d ${LIBS}
	unzip -j ${TIFF}.zip bin/libtiff-5.dll -d ${LIBS}
	unzip -j ${GIFLIB}.zip bin/libgif-7.dll -d ${LIBS}
	unzip -j ${LIBRSVG}.zip bin/*.dll -x bin/zlib1.dll \
	         bin/libiconv-*.dll bin/libintl-*.dll bin/libpng*.dll -d ${LIBS}
	unzip -j ${GNUTLS}.zip bin/*.dll -x bin/zlib1.dll -d ${LIBS}
	cp -p ${LIBS}/* ${PREFIX}/bin
	rm -rf ${LIBS}
	@echo ----- Done copying the libraries

psvn :
	@echo ----- Patching and byte compiling psvn.el...
	patch -o ${SITELISP}/psvn.el psvn.el psvn.el_svn1.7.diff
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/psvn.el
	@echo ----- Done installing psvn.el

exe :
	@echo ----- Building the archive...
	cd ${TMPDIR}/ && cmd /c "${INNOSETUP} ${INNOSCRIPT}"
	rm -rf ${TMPDIR}
	@echo ----- Done building the archive

create-release :
	@echo ----- Creating release on GitHub...
	if [ -e relnotes.in ]; then rm relnotes.in; fi
	git commit -a -m "Version ${VERSION}" && git push
	awk 'BEGIN { ORS=" "; print "{\"tag_name\": \"v${VERSION}\"," } \
	      /^$$/ { next } \
              (state==0) && /^# / { state=1; \
	                            print "\"name\": \"Emacs Modified for Windows ${VERSION}\", \"body\": \""; \
	                             next } \
	      (state==1) && /^# / { state=2; print "\","; next } \
	      state==1 { printf "%s\\n", $$0 } \
	      END { print "\"draft\": false, \"prerelease\": false}" }' \
	      NEWS > relnotes.in
	curl --data @relnotes.in ${REPOSURL}/releases?access_token=${OAUTHTOKEN}
	rm relnotes.in
	@echo ----- Done creating the release

upload :
	@echo ----- Getting upload URL from GitHub...
	$(eval upload_url=$(shell curl -s ${REPOSURL}/releases/latest \
	 			  | awk -F '[ {]' '/^  \"upload_url\"/ \
	                                    { print substr($$4, 2, length) }'))
	@echo ${upload_url}
	@echo ----- Uploading the installer to GitHub...
	curl -H 'Content-Type: application/zip' \
	     -H 'Authorization: token ${OAUTHTOKEN}' \
	     --upload-file ${DISTNAME}.exe \
	     -s -i "${upload_url}?&name=${DISTNAME}.exe"
	@echo ----- Done uploading the installer

publish :
	@echo ----- Publishing the web page...
	${MAKE} -C docs
	@echo ----- Done publishing

get-emacs :
	@echo ----- Fetching and unpacking Emacs...
	if [ -f ${ZIPFILE} ]; then rm ${ZIPFILE}; fi
	curl -O ftp://ftp.gnu.org/gnu/emacs/windows/${ZIPFILE}

get-psvn :
	@echo ----- Fetching psvn.el
	if [ -f psvn.el ]; then rm psvn.el; fi
	svn cat http://svn.apache.org/repos/asf/subversion/trunk/contrib/client-side/emacs/psvn.el > psvn.el && flip -u psvn.el

get-libs :
	@echo ----- Preparing library files
	rm -rf lib
	curl -OL https://sourceforge.net/projects/ezwinports/files/${LIBPNG}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${ZLIB}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${JPEG}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${TIFF}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${GIFLIB}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${LIBRSVG}.zip
	curl -OL https://sourceforge.net/projects/ezwinports/files/${GNUTLS}.zip

clean :
	rm -rf ${TMPDIR}
	cd ${ESS} && ${MAKE} clean
	cd ${AUCTEX} && ${MAKE} clean


