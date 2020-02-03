#!/usr/bin/env bash

docker build --rm -t cross-poppler .
docker run --rm -it -v  $(pwd)/build:/output cross-poppler /bin/bash -c "rm -rf /output/* && cp -r /build/pdftools.tar.gz /output/"
