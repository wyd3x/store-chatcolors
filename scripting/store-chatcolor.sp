#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <scp>
#include <smjansson>
//#include <colors>
//#include <morecolors_store>

StringMap CTrie;


enum ChatColor
{
	String:ChatColorName[STORE_MAX_NAME_LENGTH],
	String:ChatColorText[64]
}

new g_chatcolors[1024][ChatColor];
new g_chatcolorCount = 0;

new g_clientChatColors[MAXPLAYERS+1] = { -1, ... };

new Handle:g_chatcolorsNameIndex = INVALID_HANDLE;
new bool:g_databaseInitialized = false;

public Plugin:myinfo =
{
	name        = "[Store] Chat Color",
	author      = "Panduh, csgo fix by wyd3x",
	description = "Chat Colors component for [Store]",
	version     = "1.2",
	url         = "http://forums.alliedmodders.com/"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	CTrie = InitColorTrie();
	Store_RegisterItemType("chatcolor", OnEquip, LoadItem);
	Store_RegisterPluginModule("[Store] Chat Colors", "Chat Colors component for [Store]", "sm_chatcolor_version", "1.2");
}

/** 
 * Called when a new API library is loaded.
 */
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("chatcolor", OnEquip, LoadItem);
	}	
}

public Store_OnDatabaseInitialized()
{
	g_databaseInitialized = true;
}

/**
 * Called once a client is authorized and fully in-game, and 
 * after all post-connection authorizations have been performed.  
 *
 * This callback is gauranteed to occur on all clients, and always 
 * after each OnClientPutInServer() call.
 *
 * @param client		Client index.
 * @noreturn
 */
public OnClientPostAdminCheck(client)
{
	g_clientChatColors[client] = -1;
	if (!g_databaseInitialized)
		return;
	if(GetClientFromSerial(GetClientSerial(client)) == 0)
		return;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "chatcolor", Store_GetClientLoadout(client), OnGetPlayerChatColor, GetClientSerial(client));
}

public Store_OnClientLoadoutChanged(client)
{
	g_clientChatColors[client] = -1;
	if(GetClientFromSerial(GetClientSerial(client)) == 0)
		return;
	
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "chatcolor", Store_GetClientLoadout(client), OnGetPlayerChatColor, GetClientSerial(client));
}

public Store_OnReloadItems() 
{
	if (g_chatcolorsNameIndex != INVALID_HANDLE)
		CloseHandle(g_chatcolorsNameIndex);
		
	g_chatcolorsNameIndex = CreateTrie();
	g_chatcolorCount = 0;
}

public OnGetPlayerChatColor(titles[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	for (new index = 0; index < count; index++)
	{
		decl String:itemName[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(titles[index], itemName, sizeof(itemName));
		
		new chatcolor = -1;
		if (!GetTrieValue(g_chatcolorsNameIndex, itemName, chatcolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			continue;
		}
		
		g_clientChatColors[client] = chatcolor;
		break;
	}
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_chatcolors[g_chatcolorCount][ChatColorName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_chatcolorsNameIndex, g_chatcolors[g_chatcolorCount][ChatColorName], g_chatcolorCount);
	
	new Handle:json = json_load(attrs);	
	
	json_object_get_string(json, "color", g_chatcolors[g_chatcolorCount][ChatColorText], 64);
	new size = STORE_MAX_NAME_LENGTH;
	ReplaceString(g_chatcolors[g_chatcolorCount][ChatColorText], size, "{", "");
	ReplaceString(g_chatcolors[g_chatcolorCount][ChatColorText], size, "}", "");
	new String:value[STORE_MAX_NAME_LENGTH];
	CTrie.GetString(g_chatcolors[g_chatcolorCount][ChatColorText], value, STORE_MAX_NAME_LENGTH);
	Format(g_chatcolors[g_chatcolorCount][ChatColorText], size, "%s", value);
	
	//ReplaceString(g_chatcolors[g_chatcolorCount][ChatColorText], 10, "/", "\\", false);

	CloseHandle(json);

	g_chatcolorCount++;
}

public Store_ItemUseAction:OnEquip(client, itemId, bool:equipped)
{
	new String:name[32];
	Store_GetItemName(itemId, name, sizeof(name));

	if (equipped)
	{
		g_clientChatColors[client] = -1;
		
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{
		new chatcolor = -1;
		if (!GetTrieValue(g_chatcolorsNameIndex, name, chatcolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		g_clientChatColors[client] = chatcolor;
		
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if (g_clientChatColors[author] != -1)
	{
		new MaxMessageLength = MAXLENGTH_MESSAGE - strlen(name) - 5;
		Format(message, MaxMessageLength, "%s%s", g_chatcolors[g_clientChatColors[author]][ChatColorText], message, g_chatcolors[g_clientChatColors[author]][ChatColorText]);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
// Thanks to https://github.com/KissLick/ColorVariables
stock StringMap InitColorTrie() {
	StringMap hTrie = CreateTrie();
	hTrie.SetString("blue", "\x0B");
	hTrie.SetString("bluegrey", "\x0A");
	hTrie.SetString("darkblue", "\x0C");
	hTrie.SetString("dark-red", "\x02");
	hTrie.SetString("gold", "\x10");
	hTrie.SetString("green", "\x04");
	hTrie.SetString("grey", "\x08");
	hTrie.SetString("grey2", "\x0D");
	hTrie.SetString("lightgreen", "\x05");
	hTrie.SetString("light-red", "\x0F");
	hTrie.SetString("lime", "\x06");
	hTrie.SetString("orchid", "\x0E");
	hTrie.SetString("purple", "\x03");
	hTrie.SetString("red", "\x02");
	hTrie.SetString("yellow", "\x09");


	return hTrie;
}