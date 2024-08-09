#!/bin/bash
if [[ -n "$1" ]]; then
	rm -f ChallengerTimes.op
	pushd src; zip -q -r ../ChallengerTimes.op .; popd
	cp ChallengerTimes.op $1
fi
