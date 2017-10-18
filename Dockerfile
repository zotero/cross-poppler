FROM debian:jessie

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

RUN cd /build \
	&& git clone https://github.com/tpoechtrager/osxcross \
    && cd osxcross

COPY MacOSX10.11.sdk.tar.xz /build/osxcross/tarballs/MacOSX10.11.sdk.tar.xz

RUN cd /build/osxcross \
	&& echo | SDK_VERSION=10.11 OSX_VERSION_MIN=10.4 UNATTENDED=1 ./build.sh \
	&& mv /build/osxcross/target /usr/x86_64-apple-darwin15

COPY darwin.cmake /build/darwin.cmake
COPY windows_x86.cmake /build/windows_x86.cmake
COPY windows_x64.cmake /build/windows_x64.cmake

RUN cd /build/ \
	&& wget -O poppler.tar.xz https://poppler.freedesktop.org/poppler-0.60.1.tar.xz \
    && mkdir poppler \
    && tar -xf poppler.tar.xz -C poppler --strip-components=1 \
    && cd poppler \
    && sed -i '114 s/^/#/' CMakeLists.txt \
    && sed -i '116 s/^/#/' CMakeLists.txt \
    && sed -i '95,101 s/^/#/' CMakeLists.txt \
    && sed -i '3 s/^/#/' CMakeLists.txt \
    && sed -i '/^int\smain(/a freopen( argv[argc-1], "w", stdout ); argc--;' utils/pdfinfo.cc

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
        -DENABLE_CMS=OFF \
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
			-DCMAKE_CXX_FLAGS="-stdlib=libc++ -std=c++11" \
			-DCMAKE_TOOLCHAIN_FILE=../darwin.cmake \
			${COMMON_OPTIONS} \
	&& make

# Windows 32-bit
RUN cd /build/windows_x86 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-std=c++11 -mwindows" \
			-DCMAKE_EXE_LINKER_FLAGS="-static" \
			-DCMAKE_TOOLCHAIN_FILE=../windows_x86.cmake \
			${COMMON_OPTIONS} \
	&& make

# Windows 64-bit
RUN cd /build/windows_x64 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-std=c++11 -mwindows" \
			-DCMAKE_EXE_LINKER_FLAGS="-static" \
			-DCMAKE_TOOLCHAIN_FILE=../windows_x64.cmake \
			${COMMON_OPTIONS} \
	&& make

# Linux 32-bit
RUN cd /build/linux_x86 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-m32 -std=c++11" \
			-DCMAKE_EXE_LINKER_FLAGS="-static" \
			${COMMON_OPTIONS} \
	&& make

	# Linux 64-bit
RUN cd /build/linux_x64 \
	&& cmake /build/poppler \
			-DCMAKE_CXX_FLAGS="-std=c++11" \
			-DCMAKE_EXE_LINKER_FLAGS="-static" \
			${COMMON_OPTIONS} \
	&& make

RUN mkdir /build/bin \
	&& cd /build/bin \
	&& cp /build/darwin_x64/utils/pdfinfo ./pdfinfo_darwin_x64 \
	&& cp /build/darwin_x64/utils/pdftotext ./pdftotext_darwin_x64 \
	&& cp /build/windows_x86/utils/pdfinfo.exe ./pdfinfo_windows_x86.exe \
	&& cp /build/windows_x86/utils/pdftotext.exe ./pdftotext_windows_x86.exe \
	&& cp /build/windows_x64/utils/pdfinfo.exe ./pdfinfo_windows_x64.exe \
	&& cp /build/windows_x64/utils/pdftotext.exe ./pdftotext_windows_x64.exe \
	&& cp /build/linux_x86/utils/pdfinfo ./pdfinfo_linux_x86 \
    && cp /build/linux_x86/utils/pdftotext ./pdftotext_linux_x86 \
    && cp /build/linux_x64/utils/pdfinfo ./pdfinfo_linux_x64 \
    && cp /build/linux_x64/utils/pdftotext ./pdftotext_linux_x64