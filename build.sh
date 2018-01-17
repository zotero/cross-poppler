#!/usr/bin/env bash

docker build . -t cross-poppler
docker run -it -v  $(pwd)/build:/output cross-poppler /bin/bash -c "rm -rf /output/* && cp -r /build/pdftools.tar.gz /output/"
