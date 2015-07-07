echo -e "\nChecking repositories..."
YUM=`yum repolist | grep ius`
if [[ ! -z "$YUM" ]];
then
  echo "IUS Found. Continuing...."
else
  echo "Server must be subscribed to IUS repository."
  exit 1
fi
YUM=`yum repolist | grep -i epel`
if [[ ! -z "$YUM" ]];
then
  echo "EPEL Found. Continuing...."
else
  echo "Server must be subscribed to EPEL repository."
  exit 1
fi



echo "Installing Redis from IUS..."
yum -q -y install redis30u

echo "Configuring redis.conf"

cp -rp /etc/redis.conf /etc/redis.conf.original

sed -i 's/^\# unixsocket \/tmp\/redis.sock/unixsocket \/tmp\/redis.sock/g' /etc/redis.conf
sed -i 's/^# unixsocketperm 700/unixsocketperm 777/g' /etc/redis.conf

sed -i 's/^save 900 1/# save 900 1/g' /etc/redis.conf
sed -i 's/^save 300 10/# save 300 10/g' /etc/redis.conf
sed -i 's/^save 60 10000/# save 60 10000/g' /etc/redis.conf

sed -i '/^\# maxmemory <bytes>/a maxmemory 1GB' /etc/redis.conf
sed -i '/^\# maxmemory-policy volatile-lru/a maxmemory-policy allkeys-lru' /etc/redis.conf


# System / kernel config
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local

echo "
vm.overcommit_memory = 1
net.core.somaxconn = 1024
" >> /etc/sysctl.conf
sysctl -p


echo "redis soft nofile 16384" >> /etc/security/limits.conf
echo "redis hard nofile 16384" >> /etc/security/limits.conf

chkconfig redis on
/etc/init.d/redis start
chkconfig --list redis


echo "Configuring cleanup Cron job..."
yum -y -q install git

# Guess the user: 
CRONUSER=$(grep vhosts /etc/passwd | head -1 | cut -d':' -f1)

# Ask anyway (with default)
echo "Enter site code owner/SFTP user:  [$CRONUSER] "
read userinput
[ -n "$userinput" ] && CRONUSER=$userinput

# Get the script
HOMEDIR=$(getent passwd $CRONUSER | cut -d':' -f6)
cd $HOMEDIR
git clone https://github.com/samm-git/cm_redis_tools.git
cd cm_redis_tools
git submodule update --init --recursive

# Create the cron job
echo "33 2 * * * /usr/bin/php $HOMEDIR/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1,2" >> /tmp/rediscron
crontab -l -u $CRONUSER | cat - /tmp/rediscron | crontab -u $CRONUSER -

echo "Done. Crontab for $CRONUSER:"
crontab -l -u $CRONUSER 
