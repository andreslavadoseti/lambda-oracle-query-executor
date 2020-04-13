#!/usr/bin/env bash
BASEDIR=$(dirname $(readlink -f $0))
PIP_URL=https://bootstrap.pypa.io/get-pip.py
INSTANTCLIENT_BASIC_URL=https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-basiclite-linux.x64-19.6.0.0.0dbru.zip
INSTANTCLIENT_SDK_URL=https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip
FUNCTION_FILE=lambda_function.py
LAMBDA_NAME=ExecuteOracleQuery
BUILD_FOLDER="${LAMBDA_NAME}_build"
INSTANTCLIENT_BASIC_FILE=$(echo ${INSTANTCLIENT_BASIC_URL##*/})
INSTANTCLIENT_SDK_FILE=$(echo ${INSTANTCLIENT_SDK_URL##*/})
cd $BASEDIR
echo "Actual path: $(pwd)"
echo "- Validating python version"
PYTHON_VERSION=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
PYTHON_NUMBER_VERSION=$(echo "${PYTHON_VERSION//./}")
if [ $PYTHON_NUMBER_VERSION -lt 3600 ]
then 
    echo "- Python version: $PYTHON_VERSION, it's not valid, please upgrade to 3.6 or more"
    exit 1
else
    echo "- Python version: $PYTHON_VERSION, it's OK! "
fi
echo "- Validation pip version"
PIP=$(pip -V | cut -c 1-3)
if [[ $PIP != "pip" ]]; then
    echo "- Installing pip"
    wget $PIP_URL
    python get-pip.py
    pip install --upgrade pip
else
    echo "- $(pip -V)"
fi
echo "- Deleting previous build"
rm -rf $BUILD_FOLDER
rm -rf get-pip.py
rm -rf instantclient_*
echo "- Creating build folders"
mkdir -p "$BASEDIR/$BUILD_FOLDER/lib"
cd $BASEDIR/$BUILD_FOLDER/lib
echo "Actual path: $(pwd)"
echo "- Installing cx_Oracle"
pip install cx_Oracle -t .
echo "- Fixing cx_Oracle libs"
mv cx_Oracle.*.so cx_Oracle.so
rm -rf cx_Oracle-*
cd $BASEDIR
echo "Actual path: $(pwd)"
echo "- Copying libaio"
cp /lib64/libaio.so.1.0.1 $BASEDIR/$BUILD_FOLDER/lib/libaio.so.1
echo "- Downloading instant client libraries"
if [ ! -f "$INSTANTCLIENT_BASIC_FILE" ]; then
    wget $INSTANTCLIENT_BASIC_URL
fi
if [ ! -f "$INSTANTCLIENT_SDK_FILE" ]; then
    wget $INSTANTCLIENT_SDK_URL
fi
echo "- Unzip instant client libraries"
for z in instantclient-*.zip; do unzip "$z"; done
echo "- Copying instant client libraries"
UNZIPED_FOLDER=$(ls | grep "instantclient_")
cd $UNZIPED_FOLDER
echo "Actual path: $(pwd)"
cp -rp *.so* $BASEDIR/$BUILD_FOLDER/lib
echo "- Copying file $FUNCTION_FILE"
cd $BASEDIR
echo "Actual path: $(pwd)"
cp -rp $FUNCTION_FILE $BASEDIR/$BUILD_FOLDER/
echo "- Packaging function"
cd $BASEDIR/$BUILD_FOLDER/lib
echo "Actual path: $(pwd)"
zip --symlinks -r9 $BASEDIR/$BUILD_FOLDER/function.zip .
cd $BASEDIR/$BUILD_FOLDER
echo "Actual path: $(pwd)"
zip -g function.zip lambda_function.py
echo "- Update lambda function"
aws lambda update-function-code --function-name $LAMBDA_NAME --zip-file fileb://function.zip