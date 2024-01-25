#!/bin/bash
cd /
./steamcmd +login anonymous +app_update 2394010 validate +quit
sudo systemctl restart pal-server
