. helpers.sh

start_test_server -line 1 -file data/chunked-big
trap "stop_test_server" EXIT
request -get / -run
