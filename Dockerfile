FROM debian:jessie

LABEL maintainer="Martynas Bagdonas <git.martynas@gmail.com>"

RUN apt-get update \
	&& apt-get -y install \
		git \
		wget \
		build-essential \
		llvm \
		llvm-dev \
		gcc-multilib \
		g++-multilib \
		mingw-w64 \
		cmake \
		automake \
		autogen \
		pkg-config \
		sed \
		clang \
		libxml2-dev \
		patch

RUN mkdir /build \
	&& mkdir /build/darwin_x64 \
	&& mkdir /build/windows_x86 \
	&& mkdir /build/windows_x64 \
	&& mkdir /build/linux_x86 \
	&& mkdir /build/linux_x64

RUN git clone https://github.com/tpoechtrager/osxcross /build/osxcross

COPY MacOSX10.11.sdk.tar.xz /build/osxcross/tarballs/MacOSX10.11.sdk.tar.xz

RUN cd /build/osxcross \
	&& echo | SDK_VERSION=10.11 OSX_VERSION_MIN=10.4 UNATTENDED=1 ./build.sh \
	&& mv /build/osxcross/target /usr/x86_64-apple-darwin15

COPY darwin_x64.cmake /build/darwin_x64.cmake
COPY windows_x86.cmake /build/windows_x86.cmake
COPY windows_x64.cmake /build/windows_x64.cmake

RUN cd /build/ \
	&& wget -O poppler.tar.xz https://poppler.freedesktop.org/poppler-0.62.0.tar.xz \
	&& mkdir poppler \
	&& tar -xf poppler.tar.xz -C poppler --strip-components=1 \
	&& cd poppler \
	&& sed -i '3 s/^/#/' CMakeLists.txt \
	&& sed -i '16 s/^/#/' CMakeLists.txt \
	&& sed -i '17 s/^/#/' CMakeLists.txt \
	&& sed -i '492 s/^/#/' CMakeLists.txt \
	&& sed -i '98,104 s/^/#/' CMakeLists.txt \
	&& sed -i '119 s/^/#/' CMakeLists.txt \
	&& sed -i '121 s/^/#/' CMakeLists.txt \
	&& sed -i "/Win32Console win32console(&argc, &argv);/a if(argc!=3 || argv[1][0]=='-' || argv[2][0]=='-') {fprintf(stderr,\"This is a custom Poppler pdfinfo build. Please use the original version!\\\\n%s\\\\n%s\\\\n%s\\\\npdfinfo <PDF-file> <output-file>\\\\n\",PACKAGE_VERSION,popplerCopyright,xpdfCopyright); return 1;} else {freopen( argv[argc-1], \"w\", stdout); argc--;}" utils/pdfinfo.cc \
	&& sed -i '5871 s/^/\/\//' poppler/TextOutputDev.cc

COPY pdftotext.cc /build/poppler/utils/pdftotext.cc

ENV COMMON_OPTIONS \
		-DCMAKE_BUILD_TYPE=release \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_GTK_TESTS=OFF \
		-DBUILD_QT4_TESTS=OFF \
		-DBUILD_QT5_TESTS=OFF \
		-DBUILD_CPP_TESTS=OFF \
		-DENABLE_SPLASH=OFF \
		-DENABLE_CPP=OFF \
		-DENABLE_GLIB=OFF \
		-DENABLE_GTK_DOC=OFF \
		-DENABLE_QT4=OFF \
		-DENABLE_QT5=OFF \
		-DENABLE_LIBOPENJPEG=unmaintained \
		-DENABLE_CMS=none \
		-DENABLE_LIBCURL=OFF \
		-DENABLE_ZLIB=OFF \
		-DENABLE_DCTDECODER=unmaintained \
		-DENABLE_ZLIB_UNCOMPRESS=OFF \
		-DSPLASH_CMYK=OFF \
		-DWITH_JPEG=OFF \
		-DWITH_PNG=OFF \
		-DWITH_TIFF=OFF \
		-DWITH_NSS3=OFF \
		-DWITH_Cairo=OFF \
		-DWITH_FONTCONFIGURATION_FONTCONFIG=OFF

# macOS 64-bit
RUN cd /build/darwin_x64 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-stdlib=libc++ -std=c++11 -Os" \
			-DCMAKE_TOOLCHAIN_FILE=../darwin_x64.cmake \
			${COMMON_OPTIONS} \
	&& make

# Windows 32-bit
RUN cd /build/windows_x86 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-std=c++11 -Os -mwindows" \
			-DCMAKE_EXE_LINKER_FLAGS="-static" \
			-DCMAKE_TOOLCHAIN_FILE=../windows_x86.cmake \
			${COMMON_OPTIONS} \
	&& make

# Windows 64-bit
#RUN cd /build/windows_x64 \
#	&& cmake /build/poppler \
#			-DCMAKE_CXX_FLAGS="-std=c++11 -Os -mwindows" \
#			-DCMAKE_EXE_LINKER_FLAGS="-static" \
#			-DCMAKE_TOOLCHAIN_FILE=../windows_x64.cmake \
#			${COMMON_OPTIONS} \
#	&& make

# Linux 32-bit
RUN cd /build/linux_x86 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-m32 -std=c++11 -Os" \
			-DCMAKE_EXE_LINKER_FLAGS="-static -pthread" \
			${COMMON_OPTIONS} \
	&& make

# Linux 64-bit
RUN cd /build/linux_x64 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-std=c++11 -Os" \
			-DCMAKE_EXE_LINKER_FLAGS="-static -pthread" \
			${COMMON_OPTIONS} \
	&& make

RUN mkdir /build/pdftools \
	&& cd /build/pdftools \
	&& cp /build/darwin_x64/utils/pdfinfo ./pdfinfo-mac \
	&& cp /build/darwin_x64/utils/pdftotext ./pdftotext-mac \
	&& cp /build/windows_x86/utils/pdfinfo.exe ./pdfinfo-win.exe \
	&& cp /build/windows_x86/utils/pdftotext.exe ./pdftotext-win.exe \
#	&& cp /build/windows_x64/utils/pdfinfo.exe ./pdfinfo_windows_x64.exe \
#	&& cp /build/windows_x64/utils/pdftotext.exe ./pdftotext_windows_x64.exe \
	&& cp /build/linux_x86/utils/pdfinfo ./pdfinfo-linux-i686 \
	&& cp /build/linux_x86/utils/pdftotext ./pdftotext-linux-i686 \
	&& cp /build/linux_x64/utils/pdfinfo ./pdfinfo-linux-x86_64 \
	&& cp /build/linux_x64/utils/pdftotext ./pdftotext-linux-x86_64

RUN cd /build/ \
	&& wget -O poppler-data.tar.gz https://poppler.freedesktop.org/poppler-data-0.4.8.tar.gz \
	&& mkdir poppler-data \
	&& tar -xf poppler-data.tar.gz -C poppler-data --strip-components=1 \
	&& cd pdftools \
	&& mkdir -p poppler-data \
	&& cd poppler-data \
	&& cp -r ../../poppler-data/cidToUnicode ./ \
	&& cp -r ../../poppler-data/cMap ./ \
	&& cp -r ../../poppler-data/nameToUnicode ./ \
	&& cp -r ../../poppler-data/unicodeMap ./ \
	&& cp -r ../../poppler-data/COPYING ./ \
	&& cp -r ../../poppler-data/COPYING.adobe ./ \
	&& cp -r ../../poppler-data/COPYING.gpl2 ./ \
	&& cd .. \
	&& tar -cvzf ../pdftools.tar.gz *
