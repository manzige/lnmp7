ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 7" /etc/redhat-release && R7=1 || R7=0
echo $ROOT
echo $CPUS
echo $R7
INSTALL_DIR="/www/server"
LOCK_DIR="$ROOT/lock"
SRC_DIR="$ROOT/src"
SRC_SUFFIX=".tar.gz"
# dependency of nginx
PCRE_DOWN="ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.gz"
PCRE_SRC="pcre-8.40"
PCRE_LOCK="$LOCK_DIR/pcre.lock"
# nginx source
NGINX_DOWN="http://nginx.org/download/nginx-1.12.0.tar.gz"
NGINX_SRC="nginx-1.12.0"
NGINX_DIR="$NGINX_SRC"
NGINX_LOCK="$LOCK_DIR/nginx.lock"
# common dependency fo nginx
COMMON_LOCK="$LOCK_DIR/nginx.common.lock"

# nginx install function
function install_nginx {
    
    [ -f $NGINX_LOCK ] && return
    echo 
    echo "install php..."
    cd $SRC_DIR
    tar -zxvf $NGINX_SRC$SRC_SUFFIX
    cd $NGINX_SRC
    make clean > /dev/null 2>&1
    sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc
    ./configure --user=www --group=www \
        --prefix=$INSTALL_DIR/$NGINX_DIR \
        --with-http_stub_status_module \
        --with-ipv6 \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_ssl_module \
        --with-http_image_filter_module
    [ $? != 0 ] && error_exit "nginx configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "nginx make err"
    make install
    [ $? != 0 ] && error_exit "nginx install err"
    [ ! -L $INSTALL_DIR/nginx ] && ln -s $INSTALL_DIR/$NGINX_SRC $INSTALL_DIR/nginx
    mkdir -p $INSTALL_DIR/nginx/conf/{vhost,rewrite}
    # default web dir
    chown -hR www:www /www/web
    # cp default conf and tp rewrite rule 
    cp -f $ROOT/nginx.conf/nginx.conf $INSTALL_DIR/nginx/conf/nginx.conf
    cp -f $ROOT/nginx.conf/thinkphp.conf $INSTALL_DIR/nginx/conf/rewrite/thinkphp.conf
    if [ $R7 == 1 ]
    then
        # auto start script for centos7
        cp -f $ROOT/nginx.conf/nginx.init.R7 /usr/lib/systemd/system/nginxd.service
        systemctl daemon-reload
        systemctl start nginxd.service
        # auto start when start system 
        systemctl enable nginxd.service
    else
        # auto start script for centos6
        cp -f $ROOT/nginx.conf/nginx.init.R6 /etc/init.d/nginxd
        # auto start when start system
        chkconfig --add nginxd
        chkconfig --level 35 nginxd on
        service nginxd start
    fi
    
    echo  
    echo "install nginx complete."
    touch $NGINX_LOCK
}

# pcre install function
# nginx rewrite depend pcre
# pcre_dir=/usr
function install_pcre {
    [ -f $PCRE_LOCK ] && return
    echo "install pcre..."
    cd $SRC_DIR
    tar -zxvf $PCRE_SRC$SRC_SUFFIX
    cd $PCRE_SRC
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "pcre configure err"
    make
    [ $? != 0 ] && error_exit "pcre make err"
    make install
    [ $? != 0 ] && error_exit "pcre install err"
    # add to active lib
    ldconfig
    cd $SRC_DIR 
    rm -fr $PCRE_SRC
    
    echo
    echo "install pcre complete."
    touch $PCRE_LOCK
}

# install common dependency
# nginx gzip depend zlib zlib-devel
# nginx ssl depend openssl openssl-devel
# nginx image_filter module denpend gd gd-devel
# nginx user:group is www:www
function install_common {
    [ -f $COMMON_LOCK ] && return
    # for centos7
    iptables="iptables-services"
    yum install -y gcc gcc-c++ make cmake autoconf automake sudo wget \
        zlib zlib-devel openssl openssl-devel gd gd-devel \
        telnet ipset lsof $iptables
    [ $? != 0 ] && error_exit "common dependence install err"
    # create user for nginx and php
    groupadd -g 1000 www > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    useradd -g 1000 -u 1000 -d /www -s /sbin/nologin www > /dev/null 2>&1
   
    echo 
    echo "install common dependency complete."
    touch $COMMON_LOCK
}

# install error function
function error_exit {
    echo 
    echo 
    echo "Install error :$1--------"
    echo 
    exit
}

# start install
function start_install {
    [ ! -d $LOCK_DIR ] && mkdir -p $LOCK_DIR
    install_common
    install_pcre
    install_nginx
}

start_install