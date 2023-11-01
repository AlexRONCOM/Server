#include <open.mp>
#include <a_mysql>
#include <streamer>
#include <PawnPlus>
#include <Pawn.CMD>
#include <sscanf>
#include <foreach>

#define CMD_MODE_ALEX	1
#define CMD_MODE_REMY	0

#define function%0(%1) forward%0(%1); public%0(%1)	

#define RELEASED(%0) \
	(((newkeys & (%0)) != (%0)) && ((oldkeys & (%0)) == (%0)))

#define PRESSED(%0) \
    (((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))

#define SCM 			SendClientMessage

#define SPAWN_X -2237.61
#define SPAWN_Y 2353.63
#define SPAWN_Z 5.0
#define SPAWN_A 45.0

enum
{
	DIALOG_REGISTER,
	DIALOG_AUTHENTICATE,
	DIALOG_GARAGE,

	DIALOG_RENTCAR_ALEX,
	DIALOG_FANCY_RENTCAR_ALEX,
	DIALOG_SIMPLER_RENTCAR_ALEX,
	DIALOG_RENTCAR_TIMEOVER_ALEX,
};

enum E_PlayerData
{
	SQLID,
	Name[MAX_PLAYER_NAME],
	PassHash[65],
	Skin,
	Vehicles,
	VehicleSlots,
	PoundCash,
	DollarCash,


	bool:OpenDialog,
	AuthenticationAttempts,
	GaragePage,

	CMD_MODE,

	aRentVehicle,
	aRentTimer,
	aRentPrice,


	Cache:CacheID
};

new

MySQL:SQL,
RealPlayer[MAX_PLAYERS],
String[512],

PlayerData[MAX_PLAYERS][E_PlayerData],

Iterator:AlexVehicles<499>,
Iterator:RemyVehicles<500>,
Iterator:OnlinePlayers<MAX_PLAYERS>;

public OnGameModeInit()
{
	SQL = mysql_connect_file();

	// Alex Zone Start //

	CreateDynamicActor(46, 542.6242, -1293.5698, 17.2422, 7.4696);
	CreateDynamic3DTextLabel("Use{008080}/rentcar{FFFFFF}.", -1, 542.6242, -1293.5698, 17.2422, 5.0);

	//Alex Zone Finish //

	return 1;
}

public OnGameModeExit()
{
	mysql_close();

	return 1;
}

public OnPlayerConnect(playerid)
{
	RealPlayer[playerid]++;

	static const EmptyPlayerData[E_PlayerData];
	PlayerData[playerid] = EmptyPlayerData;

	RemoveBuildings(playerid);

	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	RealPlayer[playerid]++;

	if(IsValidTimer(PlayerData[playerid][aRentTimer]))
		KillTimer(PlayerData[playerid][aRentTimer]);

	static const EmptyPlayerData[E_PlayerData];
	PlayerData[playerid] = EmptyPlayerData;

	if(cache_is_valid(PlayerData[playerid][CacheID]))
	{
		cache_delete(PlayerData[playerid][CacheID]);
		PlayerData[playerid][CacheID] = MYSQL_INVALID_CACHE;
	}

	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if(Iter_Contains(OnlinePlayers, playerid)) return Kick(playerid);

	SetSpawnInfo(playerid, 0, 0, SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_A);
	SpawnPlayer(playerid);

	ClearChat(playerid);

	return 1;
}

public OnPlayerRequestSpawn(playerid) return Kick(playerid);

public OnPlayerSpawn(playerid)
{
	if(!Iter_Contains(OnlinePlayers, playerid))
	{
		TogglePlayerSpectating(playerid, true);

		GetPlayerName(playerid, PlayerData[playerid][Name], MAX_PLAYER_NAME);

		String[0] = 0;
		mysql_format(SQL, String, sizeof String, "SELECT * FROM ACCOUNTS WHERE NAME = '%e' LIMIT 1", PlayerData[playerid][Name]);
		mysql_tquery(SQL, String, "OnPlayerCheckAccount", "ii", playerid, RealPlayer[playerid]);
	}

	SetPlayerSkin(playerid, PlayerData[playerid][Skin]);

	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(!PlayerData[playerid][OpenDialog]) return Kick(playerid);
	PlayerData[playerid][OpenDialog] = false;

	switch(dialogid)
	{
		case DIALOG_AUTHENTICATE:
		{
			if(!response) return Kick(playerid);

			new temp[65];
			SHA256_PassHash(inputtext, "17389960", temp);
			if(!strcmp(temp, PlayerData[playerid][PassHash]))
			{
				if(cache_is_valid(PlayerData[playerid][CacheID]))
				{
					cache_set_active(PlayerData[playerid][CacheID]);

					cache_get_value_int(0, "ID", PlayerData[playerid][SQLID]);
					cache_get_value_int(0, "SKIN", PlayerData[playerid][Skin]);

					cache_delete(PlayerData[playerid][CacheID]);
					PlayerData[playerid][CacheID] = MYSQL_INVALID_CACHE;
				}

				Iter_Add(OnlinePlayers, playerid);

				TogglePlayerSpectating(playerid, false);
			}
			else
			{
				if(PlayerData[playerid][AuthenticationAttempts] == 2) return Kick(playerid);
				PlayerData[playerid][AuthenticationAttempts]++;

				SPD(playerid, DIALOG_AUTHENTICATE, DIALOG_STYLE_INPUT, "Authenticate", "-", "Authenticate", "Exit");
			}
		}
		case DIALOG_REGISTER:
		{
			if(!response) return Kick(playerid);

			if(!CheckPassHashSafety(inputtext)) return SPD(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT, "Register", "-", "Register", "Exit");

			SHA256_PassHash(inputtext, "17389960", PlayerData[playerid][PassHash]);

			String[0] = 0;
			mysql_format(SQL, String, sizeof String, "INSERT INTO ACCOUNTS (NAME, PASSHASH) VALUES ('%e', '%e')", PlayerData[playerid][Name], PlayerData[playerid][PassHash]);
			mysql_tquery(SQL, String, "OnPlayerRegister", "ii", playerid, RealPlayer[playerid]);
		}

		case DIALOG_RENTCAR_ALEX:
		{
			if(response)
				SPD(playerid, DIALOG_FANCY_RENTCAR_ALEX, DIALOG_STYLE_TABLIST_HEADERS, "{FFFFFF}Fancy Cars", "{FFFFFF}Name\t{FFFFFF}Top Speed\t{FFFFFF}Price\n{FFFFFF}Infernus\t221 km/h\t3500{D0ACEB}£{FFFFFF}\n{FFFFFF}Bullet\t203 km/h\t3000{D0ACEB}£{FFFFFF}\n{FFFFFF}Turismo\t193 km/h\t2800{D0ACEB}£{FFFFFF}\n{FFFFFF}Cheetah\t192 km/h\t2500{D0ACEB}£{FFFFFF}\n{FFFFFF}ZR-350\t186 km/h\t2000{D0ACEB}£{FFFFFF}\n{FFFFFF}Sultan\t169 km/h\t1850{D0ACEB}£{FFFFFF}", "{FFFFFF}Rent", "{FFFFFF}Quit"); 
			
			else
				SPD(playerid, DIALOG_SIMPLER_RENTCAR_ALEX, DIALOG_STYLE_TABLIST_HEADERS, "{FFFFFF}Simpler Cars", "{FFFFFF}Name\t{FFFFFF}Top Speed\t{FFFFFF}Price\n{FFFFFF}Premier\t173 km/h\t1000{D0ACEB}£{FFFFFF}\n{FFFFFF}Flash\t165 km/h\t800{D0ACEB}£{FFFFFF}\n{FFFFFF}Club\t162 km/h\t600{D0ACEB}£{FFFFFF}\n{FFFFFF}Majestic\t157 km/h\t500{D0ACEB}£{FFFFFF}\n{FFFFFF}Greenwood\t140 km/h\t300{D0ACEB}£{FFFFFF}", "{FFFFFF}Rent", "{FFFFFF}Quit"); 
		}

		case DIALOG_FANCY_RENTCAR_ALEX:
		{
			switch(listitem)
			{
				case 0:
				{
					if(PlayerData[playerid][PoundCash] < 3500)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 3500;
					PlayerData[playerid][aRentPrice] = 3500;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(411, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 1:
				{
					if(PlayerData[playerid][PoundCash] < 3000)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 3000;
					PlayerData[playerid][aRentPrice] = 3000;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(541, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 2:
				{
					if(PlayerData[playerid][PoundCash] < 2800)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 2800;
					PlayerData[playerid][aRentPrice] = 2800;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(451, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 3:
				{
					if(PlayerData[playerid][PoundCash] < 2500)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 2500;
					PlayerData[playerid][aRentPrice] = 2500;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(415, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 4:
				{
					if(PlayerData[playerid][PoundCash] < 2000)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 2000;
					PlayerData[playerid][aRentPrice] = 2000;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(477, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 5:
				{
					if(PlayerData[playerid][PoundCash] < 1850)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 1850;
					PlayerData[playerid][aRentPrice] = 1850;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(560, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}
			}


			SetVehicleNumberPlate(PlayerData[playerid][aRentVehicle], "RentCar LS");
			PutPlayerInVehicle(playerid, PlayerData[playerid][aRentVehicle], 0);
			PlayerData[playerid][aRentTimer] = SetTimerEx("RentCarTime", 1000*3600, false, "i", playerid);
		}

		case DIALOG_SIMPLER_RENTCAR_ALEX:
		{
			switch(listitem)
			{
				case 0:
				{
					if(PlayerData[playerid][PoundCash] < 1000)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 1000;
					PlayerData[playerid][aRentPrice] = 1000;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(426, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 1:
				{
					if(PlayerData[playerid][PoundCash] < 800)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 800;
					PlayerData[playerid][aRentPrice] = 800;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(565, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 2:
				{
					if(PlayerData[playerid][PoundCash] < 600)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 600;
					PlayerData[playerid][aRentPrice] = 600;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(589, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 3:
				{
					if(PlayerData[playerid][PoundCash] < 500)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 500;
					PlayerData[playerid][aRentPrice] = 500;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(517, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}

				case 4:
				{
					if(PlayerData[playerid][PoundCash] < 300)
						return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
					
					PlayerData[playerid][PoundCash] -= 300;
					PlayerData[playerid][aRentPrice] = 300;
					GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
					PlayerData[playerid][aRentVehicle] = CVA(492, 522.2725, -1291.0531, 17.0331, 0.0000, -1, -1, -1);
				}
			}


			SetVehicleNumberPlate(PlayerData[playerid][aRentVehicle], "RentCar LS");
			PutPlayerInVehicle(playerid, PlayerData[playerid][aRentVehicle], 0);
			PlayerData[playerid][aRentTimer] = SetTimerEx("RentCarTime", 1000*3600, false, "i", playerid);
		}

		case DIALOG_RENTCAR_TIMEOVER_ALEX:
		{
			if(!response)
			{
				DVA(PlayerData[playerid][aRentVehicle]);
				PlayerData[playerid][aRentVehicle] = 0;
				PlayerData[playerid][aRentTimer] = 0;

			}
			else
			{
				PlayerData[playerid][PoundCash] -= PlayerData[playerid][aRentPrice];
				GivePlayerMoney(playerid, -PlayerData[playerid][aRentPrice]);
				SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} Your rent time was extended for one more hour.");
				PlayerData[playerid][aRentTimer] = SetTimerEx("RentCarTime", 1000*3600, false, "i", playerid);
			}
		}	
	}

	return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
	SetPlayerPos(playerid, fX, fY, fZ);

	return 1;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
	if(RELEASED(KEY_NO))
	{
		switch(PlayerData[playerid][CMD_MODE])
		{
			case CMD_MODE_ALEX: PlayerData[playerid][CMD_MODE] = CMD_MODE_REMY, SCM(playerid, 0xFF0033FF, "Remy Mode On");
			case CMD_MODE_REMY: PlayerData[playerid][CMD_MODE] = CMD_MODE_ALEX, SCM(playerid, 0x008080FF, "Alex Mode On");
		}
	}

	return 1;
}

function OnPlayerCheckAccount(playerid, realplayer)
{
	if(realplayer != RealPlayer[playerid]) return Kick(playerid);

	if(cache_num_rows())
	{
		cache_get_value(0, "PASSHASH", PlayerData[playerid][PassHash], 65);
		PlayerData[playerid][CacheID] = cache_save();

		SPD(playerid, DIALOG_AUTHENTICATE, DIALOG_STYLE_INPUT, "Authenticate", "-", "Authenticate", "Exit");
	}
	else SPD(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT, "Register", "-", "Register", "Exit");

	return 1;
}

function OnPlayerRegister(playerid, realplayer)
{
	if(realplayer != RealPlayer[playerid]) return Kick(playerid);

	PlayerData[playerid][SQLID] = cache_insert_id();
	PlayerData[playerid][Skin] = 250;

	SPD(playerid, DIALOG_AUTHENTICATE, DIALOG_STYLE_INPUT, "Authenticate", "-", "Authenticate", "Exit");

	return 1;
}

//Alex Zone Start//

stock CVA(modelid, Float:spawnX, Float:spawnY, Float:spawnZ, Float:angle, colour1, colour2, respawnDelay)
{
	if(Iter_Count(AlexVehicles)  == 499)
		return 0;

	new carid = CreateVehicle(modelid, spawnX, spawnY, spawnZ, angle, colour1, colour2, respawnDelay, false);
	Iter_Add(AlexVehicles, carid);
	return carid;
}

stock DVA(vehicleid)
{
	DestroyVehicle(vehicleid);
	Iter_Remove(AlexVehicles, vehicleid);

}

CMD:test(playerid)
{
	RentCarTimer(playerid);
	return 1;
}

CMD:money(playerid, params[])
{
	GivePlayerMoney(playerid, strval(params));
	PlayerData[playerid][PoundCash] += strval(params);
	return 1;
}

function RentCarTimer(playerid)
{
	if(PlayerData[playerid][PoundCash] < 3500)
	{
		SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enough money!");
		DVA(PlayerData[playerid][aRentVehicle]);
		PlayerData[playerid][aRentVehicle] = 0;
		PlayerData[playerid][aRentTimer] = 0;
	}
	
	else
		SPD(playerid, DIALOG_RENTCAR_TIMEOVER_ALEX, DIALOG_STYLE_MSGBOX, "{FFFFFF}Time Over", "Your rent time expired!\n{FFFFFF}Do you want to pay for one more hour?", "{FFFFFF}Yes", "{FFFFFF}No");

	return 1;
}
//Alex Zone Finish//

stock CVR(modelid, Float:spawnX, Float:spawnY, Float:spawnZ, Float:angle, colour1, colour2, respawnDelay)
{
	if(Iter_Count(RemyVehicles)  == 500)
		return 0;

	new carid = CreateVehicle(modelid, spawnX, spawnY, spawnZ, angle, colour1, colour2, respawnDelay, false);
	Iter_Add(RemyVehicles, carid);
	return carid;
}

stock DVR(vehicleid)
{
	DestroyVehicle(vehicleid);
	Iter_Remove(RemyVehicles, vehicleid);
}

SPD(playerid, dialogid, DIALOG_STYLE:style, const title[], const body[], const button1[], const button2[], OPEN_MP_TAGS:...)
{
	PlayerData[playerid][OpenDialog] = true;
	return ShowPlayerDialog(playerid, dialogid, style, title, body, button1, button2);
}


RemoveBuildings(playerid)
{
	RemoveBuildingForPlayer(playerid, 1440, -2244.2344, 2361.2031, 4.4453, 0.25);
	RemoveBuildingForPlayer(playerid, 1264, -2247.6328, 2364.8594, 4.3828, 0.25);
	RemoveBuildingForPlayer(playerid, 1264, -2246.7734, 2364.4922, 4.3828, 0.25);
	RemoveBuildingForPlayer(playerid, 1264, -2246.8125, 2365.7578, 4.3828, 0.25);
	RemoveBuildingForPlayer(playerid, 1431, -2245.7109, 2363.3047, 4.5000, 0.25);
	RemoveBuildingForPlayer(playerid, 1227, -2253.5391, 2372.5469, 4.7578, 0.25);
	RemoveBuildingForPlayer(playerid, 1264, -2254.0859, 2371.0313, 4.3828, 0.25);
	RemoveBuildingForPlayer(playerid, 1264, -2252.5391, 2371.0234, 4.3828, 0.25);
	return 1;
}

stock CheckPassHashSafety(const str[])
{
	new len = strlen(str);
	if(len < 10) return 0;
	new hasUpper, hasLower, hasDigit;
	for(new i; i < len; i++)
	{
		if(str[i] >= 'A' && str[i] <= 'Z' && !hasUpper) hasUpper = 1;
		if(str[i] >= 'a' && str[i] <= 'z' && !hasUpper) hasLower = 1;
		if(str[i] >= '0' && str[i] <= '9' && !hasUpper) hasDigit = 1;
	}
	if(hasUpper + hasLower + hasDigit != 3) return 1;
	return 0;
}

stock ClearChat(playerid) { for(new i; i < 100; i++) SendClientMessage(playerid, -1, ""); }

// Alex Zone Start //

// Alex Zone Finish //


CMD:rentcar(playerid, params[])
{
	switch(PlayerData[playerid][CMD_MODE])
	{
		// Alex Zone Start //

		case CMD_MODE_ALEX:
		{
			if(IsValidTimer(PlayerData[playerid][aRentTimer]))
				return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You already have a rented car!");

			if(!IsPlayerInRangeOfPoint(playerid, 2.0, 542.6242, -1293.5698, 17.2422))
				return SCM(playerid, -1, "{008080}Info:{FFFFFF} You're to far away from the rentcar!");

			if(PlayerData[playerid][PoundCash] < 300)
				return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} You don't have enogh money to rent a car!");

			if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
				return SCM(playerid, -1, "{AAAAAA}RentCar:{FFFFFF} Please exit from the vehicle!");

			SPD(playerid, DIALOG_RENTCAR_ALEX, DIALOG_STYLE_MSGBOX, "{FFFFFF}Rent Car", "{FFFFFF}Hello!\n{FFFFFF}Would you like a more fancy car or something simpler?", "{FFFFFF}Fancy", "{FFFFFF}Simpler");
		}

		// Alex Zone Finish //
	}

	return 1;
}



#pragma warning disable 234
