checkin:
	git remote set-url origin https://brandlw@git.brz.gv.at/bitbucket/scm/izsdbdb2/RESTORE.git
	git add --all
	git commit -m "`date`"
	git push -u origin master

