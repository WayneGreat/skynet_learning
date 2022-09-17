#!/bin/bash
# $1: 文件夹后缀
# $2: pb、proto文件名
protoc --descriptor_set_out ./proto/proto_$1/$2.pb ./proto/proto_$1/$2.proto