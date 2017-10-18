#!/usr/bin/env bash

docker build . -t cross-poppler
docker run -it -v  $(pwd)/output:/output cross-poppler cp -r /build/bin/. /output/