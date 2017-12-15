#!/bin/bash

echo "Starting Chicken Scheme microservice"

cd /usr/src/app 

if [[ $DEBUG = "true" ]];  then 
    echo "Running interpreted"
    csi -q -include-path /app ./app.scm
else
    ./app
fi

