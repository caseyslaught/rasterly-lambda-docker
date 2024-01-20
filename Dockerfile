FROM public.ecr.aws/lambda/provided:al2.2023.11.09.15-x86_64 as rasterly_lambda_1

LABEL maintainer="Casey Slaught <casey@rasterly.com>"
LABEL authors="Casey Slaught <casey@rasterly.com>"

RUN yum install -y gcc gcc-c++ openssl-devel tar.x86_64 gzip bzip2 make cmake3 wget git;
RUN yum install -y libffi-devel libtiff-devel libjpeg-devel libsqlite3-dev;

# versions of packages
ENV \
    GDAL_VERSION=3.7.3 \
    PROJ_VERSION=9.3.0 \
    GEOS_VERSION=3.12.0 \
    GEOTIFF_VERSION=1.6.0 \
    HDF4_VERSION=4.2.15 \
    HDF5_VERSION=1.10.7 \
    NETCDF_VERSION=4.7.4 \
    NGHTTP2_VERSION=1.41.0 \
    OPENJPEG_VERSION=2.4.0 \
    LIBJPEG_TURBO_VERSION=2.0.6 \
    CURL_VERSION=7.73.0 \
    PKGCONFIG_VERSION=0.29.2 \
    SZIP_VERSION=2.1.1 \
    WEBP_VERSION=1.1.0 \
    ZSTD_VERSION=1.4.5 \
    OPENSSL_VERSION=1.1.1

# paths to things
ENV \
    BUILD=/build \
    NPROC=4 \
    PREFIX=/usr/local \
    GDAL_CONFIG=/usr/local/bin/gdal-config \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib64/pkgconfig \
    GDAL_DATA=/usr/local/share/gdal \
    PROJ_LIB=/usr/local/share/proj \
    SRC_DIR=/var/task

ENV LD_LIBRARY_PATH=$PREFIX/lib:$PREFIX/lib64:$LD_LIBRARY_PATH

ENV PATH=$PREFIX/bin/:$PATH

WORKDIR ${BUILD}


FROM rasterly_lambda_1 as rasterly_lambda_2

# sqlite is already installed on the lambda image

### dependencies

# SQLite3 (required by Python and proj)
RUN set -e && \
    mkdir sqlite3 && \
    wget -qO- https://www.sqlite.org/2023/sqlite-autoconf-3440000.tar.gz | tar xvz -C sqlite3 --strip-components=1 && \
    cd sqlite3 && \
    ./configure --prefix=$PREFIX && \
    make -j ${NPROC} install && \
    cd ${BUILD} && \
    rm -rf sqlite3;

# Python (numpy required for GDAL)
RUN set -e && \
    mkdir python3.9 && \
    cd python3.9 && \
    wget https://www.python.org/ftp/python/3.9.16/Python-3.9.16.tgz && \
    tar xzf Python-3.9.16.tgz && \ 
    cd Python-3.9.16 && \
    ./configure --enable-optimizations --with-ensurepip=install --prefix=${PREFIX} && \
    make -j ${NPROC} install && \
    python3 -m pip install numpy && \
    cd ${BUILD} && \
    rm -rf python3.9;

# Nghttp2 (required by curl)
RUN \
    mkdir nghttp2; \
    wget -qO- https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.gz \
        | tar xvz -C nghttp2 --strip-components=1; cd nghttp2; \
    ./configure --enable-lib-only --prefix=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf nghttp2;

# Curl (required by proj and GDAL)
RUN \
    mkdir curl; \
    wget -qO- https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz | tar xvz -C curl --strip-components=1; cd curl; \
    ./configure --prefix=${PREFIX} --disable-manual --disable-cookies --with-nghttp2=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf curl;

# pkg-config (required by GDAL)
RUN \
    mkdir pkg-config; \
    wget -qO- https://pkg-config.freedesktop.org/releases/pkg-config-$PKGCONFIG_VERSION.tar.gz \
        | tar xvz -C pkg-config --strip-components=1; cd pkg-config; \
    ./configure --prefix=$PREFIX --with-internal-glib CFLAGS="-O2 -Os"; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf pkg-config;

# ZSTD
RUN \
    mkdir zstd; \
    wget -qO- https://github.com/facebook/zstd/archive/v${ZSTD_VERSION}.tar.gz \
        | tar -xvz -C zstd --strip-components=1; cd zstd; \
    make -j ${NPROC} install PREFIX=$PREFIX ZSTD_LEGACY_SUPPORT=0 CFLAGS=-O1 --silent; \
    cd ${BUILD}; rm -rf zstd;


FROM rasterly_lambda_2 as rasterly_lambda_3


# GEOS
RUN \
    mkdir geos; \
    wget -qO- http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 \
        | tar xvj -C geos --strip-components=1; cd geos; \
    ./configure --enable-python --prefix=$PREFIX CFLAGS="-O2 -Os"; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf geos;

# Proj
RUN set -e && \
    mkdir proj && \
    wget -qO- http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz | tar xvz -C proj --strip-components=1 && \
    cd proj && \
    mkdir build && \ 
    cd build && \
    cmake3 -DSQLITE3_INCLUDE_DIR=$PREFIX/include -DSQLITE3_LIBRARY=$PREFIX/lib/libsqlite3.so .. && \
    cmake3 --build . && \
    cmake3 --build . --target install && \
    cd ${BUILD} && \
    rm -rf proj;



FROM rasterly_lambda_3 as rasterly_lambda_4


# GeoTIFF
RUN \
    mkdir geotiff; \
    wget -qO- https://download.osgeo.org/geotiff/libgeotiff/libgeotiff-$GEOTIFF_VERSION.tar.gz \
        | tar xvz -C geotiff --strip-components=1; cd geotiff; \
    ./configure --prefix=${PREFIX} \
        --with-proj=${PREFIX} --with-jpeg=${PREFIX} --with-zip=yes;\
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf geotiff;

# WEBP
RUN \
    mkdir webp; \
    wget -qO- https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz \
        | tar xvz -C webp --strip-components=1; cd webp; \
    CFLAGS="-O2 -Wl,-S" PKG_CONFIG_PATH="/usr/lib64/pkgconfig" ./configure --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf webp;


FROM rasterly_lambda_4 as rasterly_lambda_5


# required by GDAL
RUN python3 -m pip install numpy;

RUN set -e && \
    mkdir gdal && \
    wget -qO- http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz \
        | tar xvz -C gdal --strip-components=1 && \
    cd gdal && \
    mkdir build && \
    cd build && \
    cmake3 -DCMAKE_PREFIX_PATH=$PREFIX .. && \
    cmake3 --build . && \
    cmake3 --build . --target install && \
    cd ${BUILD} && \
    rm -rf gdal;


FROM rasterly_lambda_5 as rasterly_lambda_6


COPY requirements*.txt ./

RUN set -e && \
    python3 -m pip install awslambdaric && \
    python3 -m pip install -r requirements_pre.txt && \
    python3 -m pip install -r requirements.txt && \
    python3 -m pip install GDAL==$GDAL_VERSION;


FROM rasterly_lambda_6 as rasterly_lambda_7


#COPY src ${PREFIX}/src
COPY src ${SRC_DIR}

COPY .aws /root/.aws

#WORKDIR ${PREFIX}/src
WORKDIR ${SRC_DIR}

ENTRYPOINT [ "/usr/local/bin/python3", "-m", "awslambdaric" ]
CMD [ "handler.handle" ]
