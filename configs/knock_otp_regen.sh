#!/usr/bin/env bash
echo "1000,2000,3000,4000" > /etc/knockd.otp
for((j=0;j<10;j++)){
    echo "1000,2000,3000,4000" >> /etc/knockd.otp
}