mkdir unravel-info
cd unravel-info

rpm -qa | grep unravel > unravel-version.txt

cp -p ../db_connection_counter.py .

# tables to be cleaned up defined in tableFieldData.json
cp -p /usr/local/unravel/etc/tableFieldData.json .
cp -p /usr/local/unravel/etc/unravel.properties .
cp -p /usr/local/unravel/logs/unravel_td.log .
cp -p /usr/local/unravel/logs/unravel_s_1.log .
cp -p /usr/local/unravel/logs/unravel_hl.log .


echo 'SELECT table_schema AS "DB Name", SUM(data_length + index_length) / 1024 / 1024 / 1024 AS "DB Size (GB)" FROM information_schema.TABLES where table_schema="unravel_mysql_prod" GROUP BY table_schema' | /usr/local/unravel/install_bin/db_access.sh > mysql-unravel-db-size.txt

echo 'select TABLE_NAME, round((data_length + index_length) / 1024 / 1024 / 1024, 2) as total_size_gb, round(DATA_LENGTH / 1024 / 1024 / 1024, 2) as data_size_gb, round(INDEX_LENGTH / 1024 / 1024 / 1024, 2) as index_size_gb, TABLE_ROWS from information_schema.tables where table_schema not in ("information_schema", "mysql") order by total_size_gb desc' | /usr/local/unravel/install_bin/db_access.sh > mysql-unravel-table-size.txt

echo 'select * from information_schema.partitions where TABLE_SCHEMA="unravel_mysql_prod" and PARTITION_NAME is not null' |  /usr/local/unravel/install_bin/db_access.sh > mysql-unravel-partitions.txt

echo 'show variables like "%version%"' | /usr/local/unravel/install_bin/db_access.sh > mysql-version.txt

df -h > disk.txt

cat /proc/cpuinfo > cpu.txt

free -h > mem.txt

du -sh /usr/local/unravel > du-local-unravel.txt

du -sh /srv/unravel/* > du-srv-unravel.txt

ps aux | grep unravel > unravel-ps.txt

cat /etc/redhat-release > os.txt

# Check Db session per unravel Daemon
# NOTE: DB_HOST parameter should match the host part of JDBC URL specified via unravel.jdbc.url in unravel.properties. Otherwise, you may see empty result.
# this will generate db_session.txt
UNRAVEL_USER=unravel DB_HOST=localhost DB_PORT=5432 python db_connection_counter.py

# ElasticSearch data:
curl "localhost:4171/_cat/indices?v" > es_indices.txt
curl -v -XGET "http://localhost:4171/_mapping?pretty=true" > es_mapping.txt
curl -X GET "localhost:4171/_template/*?filter_path=*.version&pretty" > es_template.txt
curl -X GET "localhost:4171/_settings?pretty=true" > es_flash_setting.txt

cd ..
tar czvf unravel-info.tgz unravel-info

