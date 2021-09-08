#include <sourcemod>

#pragma newdecls required
#pragma semicolon 1

#define PREFIX " \x0C➤➤➤\x0B"

public Plugin myinfo = 
{
	name = "Ban disconnected",
	author = "proobs",
	description = "Ban disconnected players",
	version = "1.0",
	url = "https://github.com/proobs"
};

enum struct PlayerList {
	char steamid[64];
	char name[MAX_NAME_LENGTH];
	char ip[32];
	int time;
}
//ConVars
ConVar g_cvEnabled = null;
ConVar g_cvSourceBans = null;
ConVar g_cvPlayerListSz = null; 

//Handles
PlayerList Player; 
Database g_DB = null; 
ArrayList g_aPlayers; 

//Globals
char g_cLogFile[256];

public void OnPluginStart() {
	g_cvEnabled = CreateConVar("sm_bandisconnected_enable", "1", "Enable or disabled ban disconnected");
	g_cvSourceBans = CreateConVar("sm_bandisconnected_sourcebans", "1", "whether or not we query sourcebans DB. If false, we execute a banoffline command. Not the best idea however unless you cannot get it to work with sourcebans with this enabled...");
	g_cvPlayerListSz = CreateConVar("sm_bandisconnected_list_size", "30", "Max amount of clients alotted in the playerlist"); 
	
	g_aPlayers = new ArrayList(sizeof(PlayerList));
	BuildPath(Path_SM, g_cLogFile, sizeof(g_cLogFile), "logs/bandisconnected.log");
	Database.Connect(DB_OnConnect, "sourcebans");	
	
	RegAdminCmd("sm_bandisconnected", CMD_BanDisconnected, ADMFLAG_BAN, "Open Bandisconnected menu");
}

public void OnClientDisconnect(int client) {
	if(!g_cvEnabled.BoolValue)
		return; 
	if(CheckCommandAccess(client, "", ADMFLAG_BAN | ADMFLAG_ROOT))
		return; //no admins will be put into the list
	if(!IsClientValid(client))
		return; // prevents bots from getting into list

	Player.time = GetTime();
	GetClientName(client, Player.name, sizeof(PlayerList::name));
	GetClientAuthId(client, AuthId_Steam2, Player.steamid, sizeof(PlayerList::steamid));
	GetClientIP(client, Player.ip, sizeof(PlayerList::ip));
	
	//trunacte array
	if (g_aPlayers.Length) {
		g_aPlayers.ShiftUp(0);
		g_aPlayers.SetArray(0, Player);
		
		if (g_aPlayers.Length > g_cvPlayerListSz.IntValue) 
			g_aPlayers.Resize(g_cvPlayerListSz.IntValue);
	} else {
		g_aPlayers.PushArray(Player);
	}

}

public Action CMD_BanDisconnected(int client, int args) {
	if(!g_cvEnabled.BoolValue) {
		ReplyToCommand(client, "%s Command has been disabled", PREFIX);
	}
	
	if(!IsClientValid(client)) {
		ReplyToCommand(client, "%s You can't use this command right now!", PREFIX);
		return Plugin_Handled; 
	}
	
	if(g_aPlayers.Length == 0) {
		ReplyToCommand(client, "%s No players have disconnected since map change/server startup!", PREFIX);
		return Plugin_Handled;
	}

	char buffer[64];
	char infobuf[500];
	char arrayPos[64];
	char time[32];
	
	Menu menu = new Menu(player_menu);
	menu.SetTitle("Ban Disconnected");

	for (int i = 0; i < g_aPlayers.Length; i++) {

		g_aPlayers.GetArray(i, Player); 
		
		IntToString(i, arrayPos, sizeof(arrayPos));
		
		FormatTimeDuration(time, sizeof(time), GetTime() - Player.time);
		Format(buffer, sizeof(buffer), "%s » Left %s ago", Player.name, time);
		Format(infobuf, sizeof(infobuf), "%s", arrayPos);
		menu.AddItem(infobuf, buffer);
	}
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int player_menu(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			OpenPlayerMenu(param1, item);
			
		} case MenuAction_End: {
			delete menu; 
		}
	}
}

public void OpenPlayerMenu(int client, char[] arrayPos) {
	char buf[64], buf1[64], buf2[64], time[32];
	
	g_aPlayers.GetArray(StringToInt(arrayPos), Player);
	FormatTimeDuration(time, sizeof(time), GetTime() - Player.time);
	Format(buf, sizeof(buf), "Name: %s", Player.name);
	Format(buf1, sizeof(buf1), "SteamID: %s", Player.steamid);
	Format(buf2, sizeof(buf2), "Time Since Disconnect: %s", time);
	
	Menu menu = new Menu(player_menu2);
	menu.SetTitle("Ban Disconnected");
	menu.AddItem("", buf, ITEMDRAW_DISABLED);
	menu.AddItem("", buf1, ITEMDRAW_DISABLED);
	menu.AddItem("", buf2, ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem(arrayPos, "Ban Player?");
	menu.Display(client, MENU_TIME_FOREVER);
	menu.ExitBackButton = true; 
}

public int player_menu2(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof(item));	
			OpenBanLengthMenu(param1, item);
			
		} case MenuAction_End: {
			delete menu; 
		}
	}
}

public void OpenBanLengthMenu(int client, char[] arrayPos) {
	char option1[400], option2[400], option3[400], option4[400];
	
	g_aPlayers.GetArray(StringToInt(arrayPos), Player);
	
	Format(option1, sizeof(option1), "%s;%s", "0", arrayPos);
	Format(option2, sizeof(option2), "%s;%s", "1", arrayPos);
	Format(option3, sizeof(option3), "%s;%s", "2", arrayPos);
	Format(option4, sizeof(option4), "%s;%s", "3", arrayPos);

	Menu menu = new Menu(banlength_menu);
	menu.SetTitle("Ban Disconnected");
	menu.AddItem("", "Ban Length", ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem(option1, "1 day");
	menu.AddItem(option2, "2 days");
	menu.AddItem(option3, "3 days");
	menu.AddItem(option4, "1 week");
	menu.ExitBackButton = true; 
	menu.Display(client, MENU_TIME_FOREVER);
}

public int banlength_menu(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char item[32];
			char playerinfo[2][64];
			menu.GetItem(param2, item, sizeof(item));	
			ExplodeString(item, ";", playerinfo, sizeof(playerinfo), sizeof(playerinfo[]));
			
			if(StrEqual(playerinfo[0], "0")) {
				OpenReasonMenu(param1, playerinfo[1], "1 Day");
			} else if(StrEqual(playerinfo[0], "1")) {
				OpenReasonMenu(param1, playerinfo[1], "2 Days");
			} else if(StrEqual(playerinfo[0], "2")) {
				OpenReasonMenu(param1, playerinfo[1], "3 Days");
			} else if(StrEqual(playerinfo[0], "3")) {
				OpenReasonMenu(param1, playerinfo[1], "1 Week");
			}
		} case MenuAction_End: {
			delete menu; 
		}
	}
}

public void OpenReasonMenu(int client, char[] arrayPos, char[] length) {
	char option1[400], option2[400], option3[400];
	
	Format(option1, sizeof(option1), "%s;%s;%s", "0", arrayPos, length);
	Format(option2, sizeof(option2), "%s;%s;%s", "1", arrayPos, length);
	Format(option3, sizeof(option3), "%s;%s;%s", "2", arrayPos, length);
	
	g_aPlayers.GetArray(StringToInt(arrayPos), Player);
	Menu menu = new Menu(reason_menu);
	menu.SetTitle("Ban Disconnected");
	menu.AddItem("", "Reason", ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem(option1, "RDM & Leave");
	menu.AddItem(option2, "MFK & Leave");
	menu.AddItem(option3, "Not Listening to Admins & Leave");
	menu.ExitBackButton = true; 
	menu.Display(client, MENU_TIME_FOREVER);
}

public int reason_menu(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char item[32];
			char playerinfo[3][64];
			menu.GetItem(param2, item, sizeof(item));	
			ExplodeString(item, ";", playerinfo, sizeof(playerinfo), sizeof(playerinfo[]));

			if(StrEqual(playerinfo[0], "0"))
				OpenConfirmationMenu(param1, playerinfo[1], playerinfo[2], "RDM & Leave");
			else if(StrEqual(playerinfo[0], "1"))
				OpenConfirmationMenu(param1, playerinfo[1], playerinfo[2], "MFK & Leave");
			else if(StrEqual(playerinfo[0], "2"))
				OpenConfirmationMenu(param1, playerinfo[1], playerinfo[2], "Not Listening to Admins & Leave");

		} case MenuAction_End: {
			delete menu; 
		}
	}
}

public void OpenConfirmationMenu(int client, char[] arrayPos, char[] length, char[] reason) {
	char option1[400], option2[400], buffer[400], buffer2[400], buffer3[400], time[32];

	Format(option1, sizeof(option1), "%s;%s;%s;%s", "0", arrayPos, length, reason);
	Format(option2, sizeof(option2), "%s;%s", "1", arrayPos);
	
	g_aPlayers.GetArray(StringToInt(arrayPos), Player);
	
	FormatTimeDuration(time, sizeof(time), GetTime() - Player.time);
	Format(buffer, sizeof(buffer), "Are you sure you want to ban \"%s\"?", Player.name);
	Format(buffer2, sizeof(buffer2), "Who left %s ago", time);
	Format(buffer3, sizeof(buffer3), "For reason \"%s\" and for %s", reason, length); 
	
	Menu menu = new Menu(confirmation_menu);
	menu.SetTitle("Ban Disconnected");
	menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	menu.AddItem("", buffer2, ITEMDRAW_DISABLED);
	menu.AddItem("", buffer3, ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem(option1, "Yes");
	menu.AddItem(option2, "No");
	menu.ExitBackButton = true; 
	menu.Display(client, MENU_TIME_FOREVER);
}

public int confirmation_menu(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char item[128];
			char playerinfo[4][64];
			menu.GetItem(param2, item, sizeof(item));	
			ExplodeString(item, ";", playerinfo, sizeof(playerinfo), sizeof(playerinfo[]));
			
			if(StrEqual(playerinfo[0], "0"))
				CheckAndBan(param1, playerinfo[1], playerinfo[2], playerinfo[3]); 
			else if(StrEqual(playerinfo[0], "1"))
				PrintToChat(param1, "%s Closing menu...", PREFIX);
		} case MenuAction_End: {
			delete menu; 
		}
	}
}

public void CheckAndBan(int client, char[] arrayPos, char[] length, char[] reason) {
	g_aPlayers.GetArray(StringToInt(arrayPos), Player);
	if(g_cvSourceBans.BoolValue) {
		if(g_DB != INVALID_HANDLE) {
			if(StrEqual(length, "1 Day")) {
				InsertBan(client, 1440, Player.name, Player.steamid, reason, Player.ip, arrayPos);
			} else if(StrEqual(length, "2 Days")) {
				InsertBan(client, 2880, Player.name, Player.steamid, reason, Player.ip, arrayPos); 
			} else if(StrEqual(length, "3 Days")) {
				InsertBan(client, 4320, Player.name, Player.steamid, reason, Player.ip, arrayPos);
			} else if(StrEqual(length, "1 Week")) {
				InsertBan(client, 10080, Player.name, Player.steamid, reason, Player.ip, arrayPos);
			}
		} else {
			PrintToChat(client, "%s Sourcebans DB failed to query.. Please contact a developer to help solve the problem.", PREFIX);
		}
	} else {
		if(StrEqual(length, "1 Day")) {
			AddRegBan(client, 1440, Player.name, Player.steamid, reason, arrayPos);
		} else if(StrEqual(length, "2 Days")) {
			AddRegBan(client, 2880, Player.name, Player.steamid, reason, arrayPos);
		} else if(StrEqual(length, "3 Days")) {
			AddRegBan(client, 4320, Player.name, Player.steamid, reason, arrayPos);
		} else if(StrEqual(length, "1 Week")) {
			AddRegBan(client, 10080, Player.name, Player.steamid, reason, arrayPos); 
		}
	}
}

//RegBan section
public void AddRegBan(int client, int time, char[] name, char[] steamid, char[] reason, char[] arrayPos) {
	AdminId admin = GetUserAdmin(client);
	bool root = GetAdminFlag(admin, Admin_Root);
	
	SetAdminFlag(admin, Admin_Root, true);
	//In sourcebans it'll show no name for the client, but will have admin id and stuffs on there, this is only the method that should be used if the sb querying one doesnt work
	FakeClientCommand(client, "sm_addban %d %s \"%s\"", time, steamid, reason);
	SetAdminFlag(admin, Admin_Root, root); //removes root if they dont have, if they do they keep it
	
	PrintToChatAll("%s %N has banned %s for %d minutes, reason: %s", PREFIX, client, name, time, reason);
	LogAction(client, -1, "\"%L\" added ban (minutes \"%d\") (reason \"%s\")", client, time, reason);
	
	int arrayPosition = StringToInt(arrayPos);
	g_aPlayers.Erase(arrayPosition);
}

//SQL Queries to sourcebans DB
public void DB_OnConnect(Database db, const char[] error, any data) {
	if(g_cvSourceBans.BoolValue) {
		if (db == null) {
			LogToFile(g_cLogFile, "Unable to connect to sourcebans database, error %s", error);
		} else {
			g_DB = db;
		}
	}
}	

public void InsertBan(int client, int time, char[] name, char[] steamid, char[] reason, char[] ip, char[] arrayPos) {
	//SB Prefix 
	char DatabasePrefix[10] = "sb"; 
	//Query
	char cQuery[1000];
	FormatEx(cQuery, sizeof cQuery, "SELECT bid FROM %s_bans WHERE type = 0 AND authid = '%s' AND (length = 0 OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, steamid);
	//Datapack for storing info
	DataPack dataPack = new DataPack(); 
	//Admin Info
	dataPack.WriteCell(client);
	//
	dataPack.WriteString(DatabasePrefix);
	int arrayPosition = StringToInt(arrayPos);
	dataPack.WriteCell(arrayPosition);
	//Target Info
	dataPack.WriteCell(time);
	dataPack.WriteString(name);
	dataPack.WriteString(reason);
	dataPack.WriteString(ip);
	dataPack.WriteString(steamid);
	
	g_DB.Query(SBAddBanCallback, cQuery, dataPack, DBPrio_High); 
}

public void SBAddBanCallback(Database db, DBResultSet results, const char[] error, DataPack dataPack) {
	char adminIP[30];
	char ip[30]; 
	char adminID[30];
	char steamid[30];
	char DatabasePrefix[10];
	char reason[30];
	char name[64];
	
	int client; 
	int time;
	int arrayPosition;
	
	dataPack.Reset();
	//Unpacking admin info
	client = dataPack.ReadCell();
	GetClientIP(client, adminIP, sizeof(adminIP)); 
	GetClientAuthId(client, AuthId_Steam2, adminID, sizeof(adminID));
	//
	dataPack.ReadString(DatabasePrefix, sizeof(DatabasePrefix));
	arrayPosition = dataPack.ReadCell();
	//Unpacking target info
	time = dataPack.ReadCell();
	dataPack.ReadString(name, sizeof(name));
	dataPack.ReadString(steamid, sizeof(steamid));
	dataPack.ReadString(reason, sizeof(reason));
	dataPack.ReadString(ip, sizeof(ip));
	
	if(results == null) {
		LogToFile(g_cLogFile, "BanDisconnected: Add ban query in array position %d Error: %s", arrayPosition, error);
		PrintToChat(client, "%s Failed to ban %s", PREFIX, name);
		return;
	}
	
	if(results.RowCount) {
		PrintToChat(client, "%s %s is already banned", PREFIX, name);
		return; 
	}
	
	char serverPort[32];
	GetConVarString(FindConVar("hostport"), serverPort, sizeof(serverPort));
	
	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip"));
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;
	
	char serverIP[32];
	Format(serverIP, sizeof(serverIP), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
	
	char cQuery[1000];
	FormatEx(cQuery, sizeof(cQuery), "INSERT INTO %s_bans (ip, authid, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
					('%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
					(SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1), ' ')",
		DatabasePrefix, ip, steamid, name, (time * 60), (time * 60), reason, DatabasePrefix, adminID, adminID[8], adminIP, DatabasePrefix, serverIP, serverPort);

	db.Query(SBInsertBanCallback, cQuery, dataPack, DBPrio_High);
}

public void SBInsertBanCallback(Database db, DBResultSet results, const char[] error, DataPack dataPack) {
	char ip[30]; 
	char steamid[30];
	char DatabasePrefix[10];
	char reason[30];
	char name[64];
	
	int client; 
	int time;
	int arrayPosition;
	
	if(dataPack != null) {
		dataPack.Reset();
		client = dataPack.ReadCell();
		//
		dataPack.ReadString(DatabasePrefix, sizeof(DatabasePrefix));
		arrayPosition = dataPack.ReadCell();
		//Unpacking target info
		time = dataPack.ReadCell();
		dataPack.ReadString(name, sizeof(name));
		dataPack.ReadString(steamid, sizeof(steamid));
		dataPack.ReadString(reason, sizeof(reason));
		dataPack.ReadString(ip, sizeof(ip));
		delete dataPack;
	} else {
		ThrowError("Invalid Handle in SBInsertBanCallback");
		LogToFile(g_cLogFile, "BanDisconnected: Invalid handle in SBInsertBanCallback!"); 
	}
	
	if(results == null) {
		LogToFile(g_cLogFile, "BanDisconnected: Query failed in SBInsertBanCallback, error: %s", error);
		PrintToChat(client, "%s Unable to ban player %s", PREFIX, name);
		return;
	}
	
	//Delete player from arraylist, allowing it to store more items (aka players)
	g_aPlayers.Erase(arrayPosition);
	
	PrintToChatAll("%s %N has banned %s for %d minutes, reason: %s", PREFIX, client, name, time, reason);
	LogAction(client, -1, "\"%L\" added ban to %s_bans database (minutes \"%d\") (reason \"%s\")", client, DatabasePrefix, time, reason);
}

//stocks 
stock bool IsClientValid(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client) || !IsClientConnected(client) || IsFakeClient(client))
		return false;
       
	return true;
}

stock int FormatTimeDuration(char[] buffer, int maxlen, int time) {
	int days = time / 86400; //prolly dont need this but w/e
	int hours = (time / 3600) % 24;
	int minutes = (time / 60) % 60;

	if(days) 
		return Format(buffer, maxlen, "%dd %dh %dm", days, hours, minutes);		
	
	if(hours) 
		return Format(buffer, maxlen, "%dh %dm", hours, minutes);		
	
	if(minutes)
		return Format(buffer, maxlen, "%dm", minutes);		
	
	return Format(buffer, maxlen, "%ds", time % 60);		
}