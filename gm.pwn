#include <open.mp>
#include <a_mysql>
#include <streamer>
#include <PawnPlus>
#include <Pawn.CMD>
#include <sscanf>
#include <foreach>

#define function%0(%1) forward%0(%1); public%0(%1)

#define SPAWN_X -2237.61
#define SPAWN_Y 2353.63
#define SPAWN_Z 5.0
#define SPAWN_A 0.0

enum
{
	DIALOG_REGISTER,
	DIALOG_AUTHENTICATE,
	DIALOG_GARAGE
};

enum E_PlayerData
{
	SQLID,
	Name[MAX_PLAYER_NAME],
	PassHash[65],
	Skin,
	Vehicles,
	VehicleSlots,

	bool:OpenDialog,
	AuthenticationAttempts,
	GaragePage,

	Cache:CacheID
};

new

MySQL:SQL,
RealPlayer[MAX_PLAYERS],
String[512],

PlayerData[MAX_PLAYERS][E_PlayerData],

Iterator:OnlinePlayers<MAX_PLAYERS>;

public OnGameModeInit()
{
	SQL = mysql_connect_file();

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

#pragma warning disable 234
