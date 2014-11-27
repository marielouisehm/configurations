#!/bin/bash

# This will allow us to call additional scripts relative to the present one
# (from the same dir)
current_dir="$(dirname "$BASH_SOURCE")"

# Only run these on isis, AND make sure this is a login shell
# (otherwise rsync and scp and the likes will die!)
#if [[ $HOSTNAME == 'isis' ]] && [[ ${DISPLAY} ]]
if [[ -t 0 && ( $HOSTNAME == 'isis' || $HOSTNAME == 'seth' ) ]]
then
	DEFAULT_PS1=${PS1}
	DEFAULT_PATH=${PATH}

	# Make a folder in /volatile for local scratch space
	mkdir -p /volatile/$USER

	export MINDLABPROJ='NA'
	export MINDLABENV='not set'

	gotoproj ()
	{ 
		if [ $# -ge 1 ]; then
            set_mindlabproj $1
        fi
        cd /projects/$MINDLABPROJ; 
    }
   

        short_path ()                                                     
        { export PS1="\u@\h: \W> "; }

        gitprompt ()
        {
            source "$current_dir/bash-colors.sh"
            source "$current_dir/git-prompt.sh"
            
            export PS1="\[$Green\][\w]\[$Purple\]\$(__git_ps1)\n\[$BCyan\]\u@\[$BYellow\]\h\[\033[1;33m\] \[$White\]\$ \[$Color_Off\]";
        }
    
	# change this to provide a list of projects, based on group membership!
	set_mindlabproj ()
	{
        GRPLIST=(`groups`)
        PROJLIST=()
        for grp in "${GRPLIST[@]}"; do
            if [[ $grp == mindlab_??? ]]; then 
                #echo $grp; 
                fullpth=`find /projects -maxdepth 1 -group $grp`
                projname=`basename $fullpth`
                ii=$(($ii + 1))
                PROJLIST+=($projname)
            fi
        done
		if [ $# -ge 1 ]; then
            pnum=$1 # if you already know the number...
		else
            echo "------------------"
            echo "Available projects"
            echo "------------------"
            ii=0
            for projname in "${PROJLIST[@]}"; do
                let ii+=1
                echo $ii: $projname
            done
			echo -n "Select project [1-$ii]: "
			read pnum
		fi
        if [ $pnum -gt ${#PROJLIST[@]} ]; then
            echo "Project number too large, what are you trying to do?"
            return 1
        fi
        echo "Environment variable MINDLABPROJ set to ${PROJLIST[$((${pnum} - 1))]}"
        export MINDLABPROJ=${PROJLIST[$(($pnum - 1))]}

        # check if fs_subjects_dir is present in the selected project and sets that
        # to $SUBJECTS_DIR if present
        if [[ -d /projects/$MINDLABPROJ/scratch/fs_subjects_dir ]]; then
            export SUBJECTS_DIR=/projects/$MINDLABPROJ/scratch/fs_subjects_dir
        else
            echo "Folder fs_subjects_dir not found in scratch."
            echo -n "Would you like to create it now? [Y/n] "
            read ans
            if [[ $ans == "" ]] || [[ $ans == y ]] || [[ $ans == Y ]]; then
                mkdir /projects/$MINDLABPROJ/scratch/fs_subjects_dir
                export SUBJECTS_DIR=/projects/$MINDLABPROJ/scratch/fs_subjects_dir
            fi
        fi
        echo "SUBJECTS_DIR set to: $SUBJECTS_DIR"
			
	}

	use ()
	{
		if [ $# -lt 1 ]
		then
			echo "Usage: use <environment name>"
			echo "Possible environments are: anaconda, cuda, mne, mne-stable, freesurfer"
			return 0
		fi
		ENV_NAME=$1
		#ENV_VERS=$2

		if [[ $ENV_NAME == 'epd' ]]
		then 
			export PATH=/opt/local/epd/bin:$PATH
	
			WORKON_HOME=~/.virtualenvs
			VIRTUALENVWRAPPER_PYTHON=/opt/local/epd/bin/python
		
			# This will now run off EPD
			source virtualenvwrapper.sh 
		
                elif [[ $ENV_NAME == 'anaconda' ]]
                then
			export PATH=/usr/local/common/anaconda/bin:$PATH
			export MNE_PYTHON=/opt/src/python/mne-python
			export ETS_TOOLKIT="qt4"
 


		elif [[ $ENV_NAME == 'cuda_freesurfer5.3.0' ]]
		then 
            #echo "This environment is currently not supported"

            # use the local 5.0 installation of cuda, which FS 
            # seems to require!
			export PATH=/opt/local/cuda-releases/cuda-5.0/bin:$PATH
            export LD_LIBRARY_PATH=/opt/local/cuda-releases/cuda-5.0/lib64:${LD_LIBRARY_PATH}
	

		elif [[ "$ENV_NAME" == mne* ]]
		then

			# MNE Configuration
			export MNE_ROOT=/opt/local/${ENV_NAME}

			if [ ! -d $MNE_ROOT ]
			then
				echo "Unknown MNE installation ($ENV_NAME), please check environment name."
				return 1
			fi

			export MATLAB_ROOT=/usr/local/common/matlab
			. $MNE_ROOT/bin/mne_setup_sh		

			export MNE_DATASETS_SAMPLE_PATH=/opt/local/sample_data
			# Default digital trigger line on Aarhus Triux system is:
			export MNE_TRIGGER_CH_NAME="STI101"
			if [ ! -d ~/.mne ]
			then
				echo "First time MNE-user, ~/.mne created and set up."
				source /opt/local/scripts/select_Aarhus_mne_defaults.sh
			fi

			# Save the env name of mne-something while loading freesurfer
			TMP=$ENV_NAME
			# Get freesurfer in the path too!
			use freesurfer
			# Assume mne-python will be used too!
			use anaconda
			# But don't get double-PS1!
			export PS1=${DEFAULT_PS1}
			# And tell mne-something is loaded
			export ENV_NAME=$TMP

			# Set the default SUBJECTS_DIR to the MNE sample data
			if [[ $MINDLABPROJ == 'NA' ]]
			then
				export SUBJECTS_DIR=/opt/local/sample_data/MNE-sample-data
			fi

		elif [[ $ENV_NAME == 'freesurfer' ]]
		then
			#if [[ ! -z "$ENV_VERS" ]]; then 
			#	ENV_NAME=${ENV_NAME}-${ENV_VERS}
			#fi
			export FREESURFER_HOME=/opt/local/${ENV_NAME}

			if [[ $MINDLABPROJ == 'NA' ]]
			then
				export SUBJECTS_DIR=/opt/local/sample_data/freesurfer/subjects
			fi
		    # use the local 5.0 installation of cuda, which FS 
            # seems to require!
            use cuda_freesurfer5.3.0
			. $FREESURFER_HOME/SetUpFreeSurfer.sh

		else
			echo "Unknown environment/programme: $ENV_NAME"
			return 1
		fi


		# This gets to be too much if multiple environments are loaded...
		#export PS1="($ENV_NAME): ${PS1}"
		# Just leave a subtle hint we've changed something in the path...
		#export PS1="*${PS1}"
		if [[ ${PS1}==DEFAULT_PS1 ]] 
		then
			export PS1="<$ENV_NAME>${PS1}"
		else
			echo "Multiple environments selected (use'd), only first shown..."
		fi
		export MINDLABENV=$ENV_NAME
		echo "Environment '${ENV_NAME}' selected, use command 'unuse' to reset to default."

	}
	
	unuse ()
	{
		# Simply set path & prompt back to what it was before "use" was called
		export PATH=$DEFAULT_PATH
		export PS1=$DEFAULT_PS1
		echo ""
		echo "All environments unselected (last selected: '${MINDLABENV}'), path reset to default."
		export MINDLABENV='not set'
	}
fi
