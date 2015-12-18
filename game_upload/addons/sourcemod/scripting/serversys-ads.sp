#include <sourcemod>
#include <sdkhooks>
#include <smlib>
#include <clientprefs>

#include <serversys>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "[Server-Sys] Advertisements",
	description = "Server-Sys SQL-advertisements implementation.",
	author = "cam",
	version = SERVERSYS_VERSION,
	url = SERVERSYS_URL
}

bool 		EnablePlugin = true;
ArrayList 	Ads_Array;
char 		Ads_Prefix[64];
char 		Ads_Command[128];
char 		Ads_VariableColor[32];
char 		Ads_DefaultColor[32];
float 		Ads_Interval;
int 		Ads_Current = 0;
bool 		Ads_Enabled[MAXPLAYERS+1] = {false, ...};
Handle 		Ads_Cookie;
Handle 		Ads_Timer;

int iServerID = 0;
int LoadAttempts = 0;

public void OnPluginStart(){
	LoadConfig();

	LoadTranslations("serversys.ads.phrases");

	Ads_Cookie = RegClientCookie("sys_ads_enable", "Whether or not the client wishes to see chat ads.", CookieAccess_Public);

	Ads_Array = new ArrayList(ByteCountToCells(512));
}

public void OnServerIDLoaded(int ServerID){
	iServerID = ServerID;
	Sys_LoadAdverts();
}

public void OnClientPutInServer(int client){
	Ads_Enabled[client] = true;
}

public void OnClientCookiesCached(int client){
	char enabled[16];
	GetClientCookie(client, Ads_Cookie, enabled, sizeof(enabled));

	Ads_Enabled[client] = view_as<bool>(StringToInt(enabled));
}

public void OnAllPluginsLoaded(){
	Sys_RegisterChatCommand(Ads_Command, Command_ToggleAds);
}

public void Command_ToggleAds(int client, const char[] command, const char[] args){
	if(EnablePlugin && AreClientCookiesCached(client)){
		switch(Ads_Enabled[client]){
			case true:{
				SetClientCookie(client, Ads_Cookie, "0");
				Ads_Enabled[client] = false;
				CPrintToChat(client, "%t", "Ads toggled", "disabled");
			}
			case false:{
				SetClientCookie(client, Ads_Cookie, "1");
				Ads_Enabled[client] = true;
				CPrintToChat(client, "%t", "Ads toggled", "enabled");
			}
		}
	}
}

void LoadConfig(){
	Handle kv = CreateKeyValues("Advertisements");
	char Config_Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Config_Path, sizeof(Config_Path), "configs/serversys/ads.cfg");

	if(!(FileExists(Config_Path)) || !(FileToKeyValues(kv, Config_Path))){
		Sys_KillHandle(kv);
		SetFailState("[serversys] ads :: Cannot read from configuration file: %s", Config_Path);
    }

	EnablePlugin = view_as<bool>(KvGetNum(kv, "enabled", 1));
	KvGetString(kv, "prefix", Ads_Prefix, sizeof(Ads_Prefix), "");

	KvGetString(kv, "var_color", Ads_VariableColor, sizeof(Ads_VariableColor), "{GREEN}");
	KvGetString(kv, "def_color", Ads_DefaultColor, sizeof(Ads_DefaultColor), "{DEFAULT}");

	KvGetString(kv, "command", Ads_Command, sizeof(Ads_Command), "!ads /ads !toggleads /toggleads");
	Ads_Interval = KvGetFloat(kv, "interval", 90.0);


	Sys_KillHandle(kv);
}

void Sys_LoadAdverts(int ServerID = 0){
	if(iServerID == 0)
		SetFailState("[serversys] ads :: Server ID not loaded");
	else
		ServerID = iServerID;

	char query[255];
	Format(query, sizeof(query), "SELECT text FROM adverts WHERE sid IN (0, %d);", ServerID);

	LoadAttempts++;
	Sys_DB_TQuery(Sys_LoadAdverts_CB, query, _, DBPrio_Low);
}


public void Sys_LoadAdverts_CB(Handle owner, Handle hndl, const char[] error, any data){
	if(hndl == INVALID_HANDLE){
		LogError("[serversys] ads :: Error loading advertisements: %s", error);
		return;
	}

	Ads_Array.Clear();

	char temp_string[512];

	while(SQL_FetchRow(hndl)){
		SQL_FetchString(hndl, 0, temp_string, sizeof(temp_string));
		Ads_Array.PushString(temp_string);
	}

	if(Ads_Timer != INVALID_HANDLE)
		Sys_KillHandle(Ads_Timer);

	Ads_Timer = CreateTimer((Ads_Interval != 0.0 ? Ads_Interval : 90.0), Sys_Adverts_Timer, _, TIMER_REPEAT);
}

public Action Sys_Adverts_Timer(Handle timer, any data){
	if(EnablePlugin){
		if(Ads_Array != INVALID_HANDLE){
			if(Ads_Array.Length > 0){
				if((Ads_Array.Length - 1) > Ads_Current)
					Ads_Current++;
				else
					Ads_Current = 0;

				char current_ad[512];
				Ads_Array.GetString(Ads_Current, current_ad, sizeof(current_ad));

				char server_name[64];
				Sys_GetServerName(server_name, sizeof(server_name));
				char server_ip[64];
				Sys_GetServerIP(server_ip, sizeof(server_ip));
				char server_map[128];
				GetCurrentMap(server_map, sizeof(server_map));

#if SOURCEMOD_V_MAJOR >= 1 && (SOURCEMOD_V_MINOR >= 8)

				GetMapDisplayName(server_map, server_map, sizeof(server_map));

#endif

				char server_nextmap[128];
				if(GetNextMap(server_nextmap, sizeof(server_nextmap))){

#if SOURCEMOD_V_MAJOR >= 1 && (SOURCEMOD_V_MINOR >= 8)

						GetMapDisplayName(server_nextmap, server_nextmap, sizeof(server_nextmap));

#endif

				}else
					Format(server_nextmap, sizeof(server_nextmap), "undecided");

				while(StrContains(current_ad, "{{SERVER_NAME}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_NAME}}", server_name, false);
				}
				while(StrContains(current_ad, "{{SERVER_IP}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_IP}}", server_ip, false);
				}
				while(StrContains(current_ad, "{{SERVER_MAP}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_MAP}}", server_map, false);
				}
				while(StrContains(current_ad, "{{SERVER_NEXTMAP}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_NEXTMAP}}", server_nextmap, false);
				}


				char buffer[1024];
				Format(buffer, sizeof(buffer), "%s%s", Ads_Prefix, current_ad);

				while(StrContains(buffer, "{{DEF_COLOR}}", true) != -1){
					ReplaceString(buffer, sizeof(buffer), "{{DEF_COLOR}}", Ads_DefaultColor, false);
				}
				while(StrContains(buffer, "{{VAR_COLOR}}", true) != -1){
					ReplaceString(buffer, sizeof(buffer), "{{VAR_COLOR}}", Ads_VariableColor, false);
				}


				char player_name[64];
				for(int client = 1; client <= MaxClients; client++){
					if(IsClientInGame(client) && Ads_Enabled[client]){
						GetClientName(client, player_name, sizeof(player_name));

						while(StrContains(buffer, "{{PLAYER_NAME}}", true) != -1){
							ReplaceString(buffer, sizeof(buffer), "{{PLAYER_NAME}}", player_name, false);
						}

						CPrintToChat(client, "%s", buffer);

						while(StrContains(buffer, player_name, true) != -1){
							ReplaceString(buffer, sizeof(buffer), player_name, "{{PLAYER_NAME}}", false);
						}
					}
				}
			}
		}else{
			if(LoadAttempts <= 5)
				Sys_LoadAdverts();
			else
				SetFailState("[serversys] ads :: Too many attempts to connect.");
		}
	}
}
