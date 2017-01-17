.package {
	type 0 : integer
	session 1 : integer
	ud 2 : string
}

.character_overview{
	uuid 0 : integer
	level 1 : integer
	job 2 : integer
	sex 3 : integer
	name 4 : string
	createtime 5 : string
}

.character_create{
	name 0 : string
	job 1 : integer
	sex 2 : integer
}

.character_pos{
	x 0 : integer
	y 1 : integer
	z 2 : integer
}

ping 1 {
	request {
		userid 0 : string
	}
	response {
		ok 0 : boolean
	}
}

#握手
handshake 2 {
	request {
		clientkey 0 : string
	}
	response {
		challenge 0 : string
		serverkey 1 : string
	}
}

challenge 3 {
	request {
		hmac 0 : string
	}
	response {
		result 0 : string
	}
}

#账号认证
auth 4 {
	request {
		etokens 0 : string
	}
}

#登录game
login 5 {
	request {
		handshake 0 : string
	}
	response {
		result 0 : string
	}
}

getcharacterlist 6 {
	response {
		#(uuid) is optional, means character_overview.uuid is main index.
		character 0 : *character_overview(uuid)
	}
}

charactercreate 7 {
	request {
		name 0 : string
		job 1 : integer
		sex 2 : integer
	}
	response {
		character 0 : character_overview
	}
}

characterpick 8{
	request {
		uuid 0 : integer
	}
	response {
		ok 0 : boolean
	}
}

mapready 9{
	response {
		ok 0 : boolean
	}
}

moveto 10{
	request {
		pos 0 : character_pos
	}
	response {
		pos 0 : character_pos
	}
}

quitgame 11{
	
}
