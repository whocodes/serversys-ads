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
char 		Ads_Prefix[32];
char 		Ads_Command[128];
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

	Ads_Array = new ArrayList(ByteCountToCells(128));
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
				PrintTextChat(client, "%t", "Ads toggled", "disabled");
			}
			case false:{
				SetClientCookie(client, Ads_Cookie, "1");
				Ads_Enabled[client] = true;
				PrintTextChat(client, "%t", "Ads toggled", "enabled");
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

	char temp_string[128];

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
				char current_ad[256];
				Ads_Array.GetString(Ads_Current, current_ad, sizeof(current_ad));

				char server_name[64];
				Sys_GetServerName(server_name, sizeof(server_name));
				char server_ip[64];
				Sys_GetServerIP(server_ip, sizeof(server_ip));

				while(StrContains(current_ad, "{{SERVER_NAME}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_NAME}}", server_name);
				}

				while(StrContains(current_ad, "{{SERVER_IP}}", true) != -1){
					ReplaceString(current_ad, sizeof(current_ad), "{{SERVER_IP}}", server_ip);
				}

				for(int client = 1; client <= MaxClients; client++){
					if(IsClientInGame(client) && Ads_Enabled[client])
						PrintTextChat(client, "%s%s", Ads_Prefix, current_ad);
				}
			}
		}else{
			if(LoadAttempts <= 5)
				Sys_LoadAdverts();
			else
				SetFailState("[serversys] ads :: Too many attempts to connect.");
		}

		if(Ads_Current < Ads_Array.Length){
			Ads_Current++;
		}else{
			Ads_Current = 0;
		}
	}
}
