#pragma semicolon 1

#include <SteamWorks>
#include <morecolors>
#include <No_Steam_Info>

#pragma newdecls required

ConVar
	cvApiKey,
	cvEnable;

bool bKey;

char sFile[PLATFORM_MAX_PATH];

enum
{
	UNKNOWN = 0,	//Не определено
	PIRATE,			//Пират
	LEGIT,			//Стим игрок
	NO_CHECK,		//Не проверен в стиме
	CHECK			//Проверен в стиме
}

enum struct Settings
{
	int status;					//Пират, не проверен, проверен
	bool VACBan;				//Наличие вака
	int LastBan;				//Дней с последнего бана
	int GameBans;				//Количество банов
	bool CommunityBanned;		//Баны в сообществах

	bool EconomyBan;			//Бан эконимики
	bool probation;				//На испытательном сроке
	bool banned;				//Заблокирован

	void Reset()
	{
		this.status = 0;
		this.VACBan = false;
		this.LastBan = 0;
		this.GameBans = 0;
		this.CommunityBanned = false;

		this.EconomyBan = false;
		this.probation = false;
		this.banned = false;
	}

	void getStatus(int client)
	{
		RevEmu_PlayerType NoSteam = RevEmu_GetPlayerType(client);
		switch(NoSteam)
		{
			case ErrorGet: this.status = UNKNOWN;
			case SteamLegitUser: this.status = LEGIT;
			default: this.status = PIRATE;
		}
	}
}

Settings steam[MAXPLAYERS+1];

#include "my_steam/reqest.sp"
#include "my_steam/menu.sp"

public Plugin myinfo =
{
	name = "My steam/Мой стим",
	author = "by Nek.'a 2x2 | ggwp.site ",
	description = "Подробноя инф. о игроках",
	version = "1.0.2",
	url = "ggwp.site || vk.com/nekromio || t.me/sourcepwn "
}

public void OnPluginStart() 
{
	cvEnable = CreateConVar("sm_mysteam_enable", "1", "Включить/Выключить плагин", _, true, 0.0, true, 1.0);
	
	cvApiKey = CreateConVar("sm_mysteam_key", "", "В последнее время получение информации от Valve имеет сбои или слишком медленные \nДля отключения Valve првоерки оставьте поле пустым\nВаш личный ключ api key подробнее тут(https://steamcommunity.com/dev/apikey)");
	
	BuildPath(Path_SM, sFile, sizeof(sFile), "logs/my_steam.log");
	
	RegConsoleCmd("sm_st", Cmd_MySteam);

	RegAdminCmd("sm_stall", Cmd_MySteamAll, ADMFLAG_ROOT, "Вывод списком Steam ID всех игроков");
	
	RegConsoleCmd("sm_stm", Cmd_MySteamMenu);
	
	AutoExecConfig(true, "my_steam");
}

public void OnConfigsExecuted()
{
	char buffer[256];
	cvApiKey.GetString(buffer, sizeof(buffer));

	if(buffer[0])
	{
		bKey = true;
	}

	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i)) OnClientPostAdminCheck(i);
}

public void OnClientPostAdminCheck(int client)
{
	if(!cvEnable.BoolValue || !IsClientValid(client))
		return;
	
	steam[client].getStatus(client);

	if(!bKey)
		return;

	SteamWorksConnectToApi(client);
}

public void OnClientConnected(int client)
{
	steam[client].Reset();
}

Action Cmd_MySteamMenu(int client, int args)
{
	if(!cvEnable.BoolValue)
		return Plugin_Continue;
		
	if(!client)
		return Plugin_Continue;
	
	Create_MuSteamMenu(client);

	return Plugin_Handled;
}

Action Cmd_MySteam(int client, any args)
{
	if(!cvEnable.BoolValue)
		return Plugin_Continue;
		
	if(!IsClientValid(client))
		return Plugin_Continue;
		
	SaySteam(client, false);

	return Plugin_Handled;
}

Action Cmd_MySteamAll(int client, any args)
{
	if(!cvEnable.BoolValue)
		return Plugin_Continue;
		
	SaySteam(client, true);

	return Plugin_Handled;
}

stock void SaySteam(int client, bool all = false)
{
	if(!client)
	{
		all = true;
		LogToFile(sFile, "Консоль вызавала првоерку игроков на Лицензию");
	}
		
	char sSteam[3][32];
	
	if(!all)
	{
		getSteam(client, sSteam);
		CPrintToChat(client, "▼====%s====▼", steam[client].status == PIRATE ? "[PIRATE]" : "[STEAM]");
		CPrintToChat(client, "Ник [%N]", client);
		CPrintToChat(client, "--> Steam2   %s", sSteam[0]);
		CPrintToChat(client, "--> Steam3   %s", sSteam[1]);
		CPrintToChat(client, "--> Steam64   %s", sSteam[2]);

		SteamWorksConnectToApi(client);
		switch(steam[client].status)
		{
			case UNKNOWN, PIRATE:
			{
				CPrintToChat(client, "--> Вы \x07FF0000\x0733cc33- \x07ff0000Пират \x0733cc33!");
				LogToFile(sFile, "Игрок [%N] посмотрел свой статус steam - пират!", client);
			}

			case LEGIT, NO_CHECK:
			{
				if(bKey)
				{
					CPrintToChat(client, "--> Вы Steam игрок, но ещё не прошли проверку Valve");
					LogToFile(sFile, "Игрок [%N] посмотрел свой статус steam - стим, но проверку на Vac ещё не прошёл!", client);
				}
				else
				{
					CPrintToChat(client, "--> Вы Steam игрок - лицензия!");
					LogToFile(sFile, "Игрок [%N] посмотрел свой статус steam - лицензия!", client);
				}
			}

			case CHECK:
			{
				CPrintToChat(client, "--> Вы \x07ff0000- \x0733cc33Steam \x07ff0000игрок");
				LogToFile(sFile, "Игрок [%N] посмотрел свой статус steam - лицензия!", client);
				if(!steam[client].VACBan)
				{
					CPrintToChat(client, "--> VAC Бан - [не обнаружен]");
					LogToFile(sFile, "VAC Бан - [не обнаружен]");
				}
				else
				{
					CPrintToChat(client, "--> VAC Бан - [обнаружен] | Дней от блокировки [%d]", steam[client].LastBan);
					LogToFile(sFile, "VAC Бан - [обнаружен] | Дней от блокировки [%d]", steam[client].LastBan);
				}
					
			}
		}
		LogToFile(sFile, "Его стим \n Steam2 %s\n Steam3 %s\n Steam64 %s", sSteam[0], sSteam[1], sSteam[2]);
	}
	else
	{
		if(!client)
			
		for (int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
		{
			getSteam(i, sSteam);
			PrintToConsole(client, "▼====%s====▼", steam[i].status == PIRATE ? "[PIRATE]" : "[STEAM]");
			PrintToConsole(client, "Ник [%N]", i);
			PrintToConsole(client, "--> Steam2   %s", sSteam[0]);
			PrintToConsole(client, "--> Steam3   %s", sSteam[1]);
			PrintToConsole(client, "--> Steam64   %s", sSteam[2]);

			SteamWorksConnectToApi(i);

			switch (steam[i].status)
			{
				case UNKNOWN, PIRATE:
				{
					PrintToConsole(client, "--> Игрок [%N] [No-Steam]", i);
					LogToFile(sFile, "Игрок [%N] (Steam2: %s) - No-Steam", i, sSteam[0]);
				}

				case LEGIT, NO_CHECK:
				{
					if (bKey)
					{
						PrintToConsole(client, "--> Игрок [%N] ещё не прошёл проверку Steam", i);
						LogToFile(sFile, "Игрок [%N] (Steam2: %s) - лицензия, но ещё не прошёл проверку Valve", i, sSteam[0]);
					}
					else
					{
						PrintToConsole(client, "--> Игрок [%N] лицензия!", i);
						LogToFile(sFile, "Игрок [%N] (Steam2: %s) - лицензия!", i, sSteam[0]);
					}
				}

				case CHECK:
				{
					PrintToConsole(client, "--> Игрок \x07ff0000[\x0733cc33Steam\x07ff0000]");
					LogToFile(sFile, "Игрок [%N] (Steam2: %s) - лицензия!", i, sSteam[0]);

					if (!steam[i].VACBan)
					{
						PrintToConsole(client, "--> VAC Бан - [не обнаружен]");
						LogToFile(sFile, "Игрок [%N] (Steam2: %s) - VAC Бан: не обнаружен", i, sSteam[0]);
					}
					else
					{
						PrintToConsole(client, "--> VAC Бан - [обнаружен] | Дней от блокировки [%d]", steam[i].LastBan);
						LogToFile(sFile, "Игрок [%N] (Steam2: %s) - VAC Бан: обнаружен, дней от блокировки: [%d]", i, sSteam[0], steam[i].LastBan);
					}
				}
			}
		}
	}
}

bool IsClientValid(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

int getIndex(Menu hMenu, int item)
{
    char buffer[8];
    hMenu.GetItem(item, buffer, sizeof(buffer));
    int target = StringToInt(buffer);

    return target;
}

void getSteam(int client, char sSteam[3][32])
{
    GetClientAuthId(client, AuthId_Steam2, sSteam[0], sizeof(sSteam[]));
    GetClientAuthId(client, AuthId_Steam3, sSteam[1], sizeof(sSteam[]));
    GetClientAuthId(client, AuthId_SteamID64, sSteam[2], sizeof(sSteam[]));
}