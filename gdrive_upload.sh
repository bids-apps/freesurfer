#! /bin/bash
set -o errexit
set -o nounset

app_name=$1
refresh_token=$2
file_name=$3
bids_apps_dir_id=`./gdrive list -q "name = 'bids-apps' and trashed = false and mimeType = 'application/vnd.google-apps.folder'" --refresh-token $refresh_token --no-header | cut -f1 -d " "`
echo $bids_apps_dir_id

app_dir_id=`./gdrive list -q "name = '$app_name' and '$bids_apps_dir_id' in parents and trashed = false and mimeType = 'application/vnd.google-apps.folder'" --refresh-token $refresh_token --no-header | cut -f1 -d " "`
echo $app_dir_id
if [ -z "$app_dir_id" ]
then
  ./gdrive mkdir "$app_name" -p "$bids_apps_dir_id" --refresh-token $refresh_token
	app_dir_id=`./gdrive list -q "name = '$app_name' and '$bids_apps_dir_id' in parents and trashed = false and mimeType = 'application/vnd.google-apps.folder'" --refresh-token $refresh_token --no-header | cut -f1 -d " "`
fi

echo $app_dir_id

./gdrive upload $file_name -p $app_dir_id --refresh-token $refresh_token
