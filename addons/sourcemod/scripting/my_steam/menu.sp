void Create_MuSteamMenu(int client)
{
	char
		title[128] = "Список игроков",
		index[3],
		buffer[PLATFORM_MAX_PATH];

	Menu hMenu = new Menu(Callback_MySteamMenu);
	hMenu.GetTitle(title, sizeof(title));

	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		if(steam[i].status >= LEGIT)
		{
			Format(buffer, sizeof(buffer), "%N", i);
			Format(index, sizeof(index), "%d", i);
			hMenu.AddItem(index, buffer);
		}
		else
		{
			Format(buffer, sizeof(buffer), "[PIRATE] %N", i);
			hMenu.AddItem(buffer, buffer, ITEMDRAW_DISABLED);
		}
	}
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

int Callback_MySteamMenu(Menu hMenu, MenuAction action, int client, int item)
{
	switch(action)
    {
		case MenuAction_End:
        {
            delete hMenu;
        }
		case MenuAction_Select:
        {
			int target = getIndex(hMenu, item);

            if(!IsClientValid(target))
            {
                Create_MuSteamMenu(client);
                return 0;
            }

            char sSteam[3][32];
            getSteam(target, sSteam);

            if(GetUserAdmin(client) != INVALID_ADMIN_ID)
            {
                PrintToChat(client, "Был выбран игрок [%N]\n-> Steam2 = [%s]\n-> Steam3 = %s\n-> Steam64 = [%s]", target, sSteam[0], sSteam[1], sSteam[2]);
            }

			char url[128];
			Format(url, sizeof(url), "https://steamcommunity.com/profiles/%s/", sSteam[2]);
			ShowMOTDPanel(client, "Меню с подсказкой", url, MOTDPANEL_TYPE_URL);
			PrintToChat(client, "Профиль [%N]\n[%s]", target, url);
            LogToFile(sFile, "Игрок [%N] посмотрел профиль: [%N] [%s]", client, target, url);
            Create_MuSteamMenu(client);
		}
	}
	return 0;
}