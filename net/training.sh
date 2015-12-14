#!/usr/bin/env bash

PROJECT="sentence"
SOLVER="solver_xiaoyin.prototxt"

# Check if called with name
if [ $# -ne 1 ]; then
    echo "Usage: $0 [experiment_name]"
	echo "       experiment_name: Name of the subfolder in ./experiments/ for the current experiment."
	echo "Exiting."
	exit 1
fi

# Set Vars
DATE=`date +%Y%m%d-%H%M%S`
FOLDER_NAME="${DATE}_$1"
TRAINING_LOG_NAME="${PROJECT}.tlog"

echo "Saving experiment in experiments/$FOLDER_NAME"
mkdir experiments/$FOLDER_NAME

# Function for saving results and making plots
function cleanup() {
    echo $1
    
    echo "Copying snapshots"
    ls -v -1 snapshots/ | tail -n 2 | xargs -i mv snapshots/{} experiments/$FOLDER_NAME
    
    echo "Parsing logs"
    $CAFFE_ROOT/tools/extra/parse_log.sh $TRAINING_LOG_NAME
    
    echo "Copying logs"
    cp $TRAINING_LOG_NAME $TRAINING_LOG_NAME.train $TRAINING_LOG_NAME.test experiments/$FOLDER_NAME
    
    echo "Building plots"
    gnuplot -e "filename='$TRAINING_LOG_NAME'" -p plot_log.gnuplot
    mv *.png experiments/$FOLDER_NAME
    
    rm ${TRAINING_LOG_NAME}.test ${TRAINING_LOG_NAME}.train
    echo "Clean up finished"
}

# Clean snapshots
rm snapshots/* 2> /dev/null

# Saving setup
cp net.prototxt $SOLVER training.sh experiments/$FOLDER_NAME

# Setting interrupt trap
trap 'cleanup "Training interrupted"; exit 1' INT

# Calling caffe
# export CAFFE_ROOT="$HOME/caffe-tmbo"

$CAFFE_ROOT/build/tools/caffe train \
    -solver ./experiments/$FOLDER_NAME/$SOLVER 2> $TRAINING_LOG_NAME

# Resetting interrupt handling
trap - INT

# Check if Training successful
if [ $? -ne 0 ]; then
    # Send Email Notification
    cd "${SENTENCE_HOME}/python"
    python "common/send_email.py" "training failed" "$FOLDER_NAME" "../net/$TRAINING_LOG_NAME"
    cd -
    echo "Training not successful. Exiting."
    exit 2
fi

cleanup "Training finished"

