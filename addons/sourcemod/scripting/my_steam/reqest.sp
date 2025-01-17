//Проверяем профиль стима
void SteamWorksConnectToApi(int client)
{
    if(!bKey || !IsClientValid(client) || steam[client].status == CHECK)
        return;

    char sSteam[32];
	GetClientAuthId(client, AuthId_SteamID64, sSteam, sizeof(sSteam));

	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteString(sSteam);

	char url[128], sKey[256];
	cvApiKey.GetString(sKey, sizeof(sKey));
	Format(url, sizeof(url), "https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=%s&steamids=%s", sKey, sSteam);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksHTTPComplete);
	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SendHTTPRequest(hRequest);
}

//Процес коннекта
void OnSteamWorksHTTPComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack hPack)
{
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnSteamWorksHTTPBodyCallback, hPack);
	else
		if (bRequestSuccessful)
			LogError("HTTP error: %d (using SteamWorks)", eStatusCode);
		else LogError("SteamWorks error", LANG_SERVER);
}

//Сама проверка после подключения к сайту
void OnSteamWorksHTTPBodyCallback(const char[] sData, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();

	UpdateClientStatus(client, sData);

	delete hPack;
}

/**
 * Update the client data based on the response data.
 *
 * @param client   The client index
 * @param response The response from the server
 */
void UpdateClientStatus(int client, const char[] response)
{
	steam[client].Reset();

	char responseData[1024];
	strcopy(responseData, sizeof(responseData), response);

	ReplaceString(responseData, sizeof(responseData), " ", "");
	ReplaceString(responseData, sizeof(responseData), "\t", "");
	ReplaceString(responseData, sizeof(responseData), "\n", "");
	ReplaceString(responseData, sizeof(responseData), "\r", "");
	ReplaceString(responseData, sizeof(responseData), "\"", "");
	ReplaceString(responseData, sizeof(responseData), "{players:[{", "");
	ReplaceString(responseData, sizeof(responseData), "}]}", "");
	
	char parts[16][512];
	int count = ExplodeString(responseData, ",", parts, sizeof(parts), sizeof(parts[]));
	char kv[2][64];

	for (int i = 0; i < count; i++)
	{
		if (ExplodeString(parts[i], ":", kv, sizeof(kv), sizeof(kv[])) < 2)
		{
			continue;
		}

		if (StrEqual(kv[0], "NumberOfVACBans"))		//Есть ли у игрока вак бан
		{
            steam[client].VACBan = StringToInt(kv[1]) > 0;
		}
		else if (StrEqual(kv[0], "DaysSinceLastBan"))		//Сколько прошло днеё с последней блокировки?
		{
            steam[client].LastBan = StringToInt(kv[1]);
		}
		else if (StrEqual(kv[0], "NumberOfGameBans"))	//Количество запретов
		{
            steam[client].GameBans = StringToInt(kv[1]);
		}
		else if (StrEqual(kv[0], "CommunityBanned"))	//Баны сообществ
		{
            steam[client].CommunityBanned = StrEqual(kv[1], "true", false);
		}
		else if (StrEqual(kv[0], "EconomyBan"))		//Экономический запрет
		{
            steam[client].EconomyBan = true;

			if (StrEqual(kv[1], "probation", false))	//Испытательный срок
			{
                steam[client].probation = true;
			}
			else if (StrEqual(kv[1], "banned", false))		//Запрещен
			{
                steam[client].banned = true;
			}
		}
	}
}