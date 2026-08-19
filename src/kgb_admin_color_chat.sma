#include <amxmodx>
#include <amxmisc>
#include <file>

#pragma semicolon 1

#define PLUGIN_NAME "KGB Admin color chat"
#define PLUGIN_VERSION "1.1"
#define PLUGIN_AUTHOR "KGB Hosting"

#define CONFIG_FILE "addons/amxmodx/configs/kgb_admin_color_chat.cfg"
#define CONFIG_DIR "addons/amxmodx/configs"

#define CHAT_BUFFER 192
#define SMALL_BUFFER 64

new g_SayText;
new g_CvarBroadcasts;
new g_CvarAdminChat;
new g_CvarPrivateMessages;
new g_CvarLogging;

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	server_print("[KGB] %s v%s loaded", PLUGIN_NAME, PLUGIN_VERSION);

	g_SayText = get_user_msgid("SayText");

	g_CvarBroadcasts = register_cvar("kgb_acc_broadcasts", "1");
	g_CvarAdminChat = register_cvar("kgb_acc_admin_chat", "1");
	g_CvarPrivateMessages = register_cvar("kgb_acc_private_messages", "1");
	g_CvarLogging = register_cvar("kgb_acc_logging", "1");

	CreateDefaultConfig();
	server_cmd("exec %s", CONFIG_FILE);
	server_exec();

	register_clcmd("say", "SayHandler", ADMIN_CHAT, "# <name or #userid> <message> - Sends a PM");
	register_clcmd("say_team", "SayTeamHandler", ADMIN_ALL, "@ <message> - Displays message to admins");
	register_concmd("amx_say", "ConCmdACCSay", ADMIN_CHAT, "<message> - Displays message to all players");
	register_concmd("amx_psay", "ConCmdACCPM", ADMIN_CHAT, "# <name or #userid> <message> - Sends a PM");
	register_concmd("amx_chat", "ConCmdACCAdmins", ADMIN_CHAT, "<message> - Displays message to admins");
}

public SayHandler(id, level, cid)
{
	new message[CHAT_BUFFER];
	read_args(message, charsmax(message));
	remove_quotes(message);
	trim(message);

	if (message[0] != '#')
	{
		return PLUGIN_CONTINUE;
	}

	if (!HasAdminChat(id))
	{
		return PLUGIN_CONTINUE;
	}

	if (!PrivateMessagesEnabled())
	{
		ReportError(id, "^x04[KGB]: Private messages are disabled");
		return PLUGIN_HANDLED;
	}

	HandlePrivateMessageCommand(id, message[1]);
	return PLUGIN_HANDLED;
}

public SayTeamHandler(id, level, cid)
{
	new message[CHAT_BUFFER];
	read_args(message, charsmax(message));
	remove_quotes(message);
	trim(message);

	if (message[0] == '@')
	{
		if (!AdminChatEnabled())
		{
			ReportError(id, "^x04[KGB]: Admin chat is disabled");
			return PLUGIN_HANDLED;
		}

		new adminMessage[CHAT_BUFFER];
		copy(adminMessage, charsmax(adminMessage), message[1]);
		trim(adminMessage);

		if (adminMessage[0])
		{
			SendAdminMessage(id, adminMessage, true);
			LogAdminMessage(id, adminMessage);
		}

		return PLUGIN_HANDLED;
	}

	if (message[0] == '#' && HasAdminChat(id))
	{
		if (!PrivateMessagesEnabled())
		{
			ReportError(id, "^x04[KGB]: Private messages are disabled");
			return PLUGIN_HANDLED;
		}

		HandlePrivateMessageCommand(id, message[1]);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public ConCmdACCSay(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
	{
		return PLUGIN_HANDLED;
	}

	if (!BroadcastsEnabled())
	{
		console_print(id, "KGB Admin Color Chat: admin broadcasts are disabled.");
		return PLUGIN_HANDLED;
	}

	new message[CHAT_BUFFER];
	read_args(message, charsmax(message));
	remove_quotes(message);
	trim(message);

	if (!message[0])
	{
		return PLUGIN_HANDLED;
	}

	new senderName[32], senderAuth[35], senderUserid;
	GetActorInfo(id, senderName, charsmax(senderName), senderAuth, charsmax(senderAuth), senderUserid);

	new line[CHAT_BUFFER];
	format(line, charsmax(line), "^x04%s    : ^x01%s", senderName, message);

	new players[32], playerCount;
	get_players(players, playerCount, "ch");

	for (new i = 0; i < playerCount; i++)
	{
		SendSayText(players[i], id, line);
	}

	console_print(id, "%s    : %s", senderName, message);

	if (LoggingEnabled())
	{
		log_amx("Chat (ALL), From: ^"%s<%d><%s><>^" Message: ^"%s^"", senderName, senderUserid, senderAuth, message);
		log_message("^"%s<%d><%s><>^" triggered ^"amx_say^" (text ^"%s^")", senderName, senderUserid, senderAuth, message);
	}

	return PLUGIN_HANDLED;
}

public ConCmdACCPM(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
	{
		return PLUGIN_HANDLED;
	}

	if (!PrivateMessagesEnabled())
	{
		console_print(id, "KGB Admin Color Chat: private messages are disabled.");
		return PLUGIN_HANDLED;
	}

	new args[CHAT_BUFFER];
	read_args(args, charsmax(args));
	remove_quotes(args);
	trim(args);

	HandlePrivateMessageCommand(id, args);
	return PLUGIN_HANDLED;
}

public ConCmdACCAdmins(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
	{
		return PLUGIN_HANDLED;
	}

	if (!AdminChatEnabled())
	{
		console_print(id, "KGB Admin Color Chat: admin chat is disabled.");
		return PLUGIN_HANDLED;
	}

	new message[CHAT_BUFFER];
	read_args(message, charsmax(message));
	remove_quotes(message);
	trim(message);

	if (!message[0])
	{
		return PLUGIN_HANDLED;
	}

	SendAdminMessage(id, message, false);
	LogAdminMessage(id, message);

	return PLUGIN_HANDLED;
}

stock HandlePrivateMessageCommand(id, const args[])
{
	new target[SMALL_BUFFER], message[CHAT_BUFFER];

	if (!SplitTargetAndMessage(args, target, charsmax(target), message, charsmax(message)))
	{
		ReportLookupError(id, 3);
		return;
	}

	new status;
	new recipient = ResolvePrivateMessageTarget(target, status);

	if (!recipient)
	{
		ReportLookupError(id, status);
		return;
	}

	SendPrivateMessage(id, recipient, message);
}

stock bool:SplitTargetAndMessage(const input[], target[], targetLen, message[], messageLen)
{
	new args[CHAT_BUFFER];
	copy(args, charsmax(args), input);
	trim(args);

	if (args[0] == '#' && isspace(args[1]))
	{
		new stripped[CHAT_BUFFER];
		copy(stripped, charsmax(stripped), args[1]);
		copy(args, charsmax(args), stripped);
		trim(args);
	}

	if (!args[0])
	{
		return false;
	}

	SplitFirstArgument(args, target, targetLen, message, messageLen);
	trim(target);
	trim(message);

	replace_all(target, targetLen, "^"", "");
	trim(target);

	if (target[0] == '#' && target[1] && !is_str_num(target[1]))
	{
		new strippedTarget[SMALL_BUFFER];
		copy(strippedTarget, charsmax(strippedTarget), target[1]);
		copy(target, targetLen, strippedTarget);
		trim(target);
	}

	if (!target[0] || !message[0])
	{
		return false;
	}

	remove_quotes(message);
	trim(message);

	return message[0] ? true : false;
}

stock SplitFirstArgument(const input[], left[], leftLen, right[], rightLen)
{
	new pos = 0;
	new out = 0;
	new bool:quoted = false;

	while (input[pos] && isspace(input[pos]))
	{
		pos++;
	}

	if (input[pos] == '^"')
	{
		quoted = true;
		pos++;
	}

	while (input[pos])
	{
		if (quoted)
		{
			if (input[pos] == '^"')
			{
				pos++;
				break;
			}
		}
		else if (isspace(input[pos]))
		{
			break;
		}

		if (out < leftLen)
		{
			left[out++] = input[pos];
		}

		pos++;
	}

	left[out] = 0;

	while (input[pos] && isspace(input[pos]))
	{
		pos++;
	}

	copy(right, rightLen, input[pos]);
}

stock ResolvePrivateMessageTarget(const target[], &status)
{
	status = 3;

	if (target[0] == '#')
	{
		new userid = str_to_num(target[1]);
		if (userid <= 0)
		{
			status = 2;
			return 0;
		}

		return FindPlayerWithUserid(userid, status);
	}

	if (equal(target, "STEAM_", 6))
	{
		return FindPlayerWithSteamId(target, status);
	}

	return FindPlayerWithNick(target, status);
}

stock FindPlayerWithUserid(userid, &status)
{
	new players[32], playerCount;
	get_players(players, playerCount, "ch");

	for (new i = 0; i < playerCount; i++)
	{
		if (get_user_userid(players[i]) == userid)
		{
			status = 0;
			return players[i];
		}
	}

	status = 2;
	return 0;
}

stock FindPlayerWithSteamId(const steamId[], &status)
{
	new players[32], playerCount, authId[35];
	get_players(players, playerCount, "ch");

	for (new i = 0; i < playerCount; i++)
	{
		get_user_authid(players[i], authId, charsmax(authId));

		if (equal(authId, steamId))
		{
			status = 0;
			return players[i];
		}
	}

	status = 2;
	return 0;
}

stock FindPlayerWithNick(const nick[], &status)
{
	new players[32], playerCount, name[32];
	new matchedPlayer = 0;
	new matches = 0;

	get_players(players, playerCount, "ch");

	for (new i = 0; i < playerCount; i++)
	{
		get_user_name(players[i], name, charsmax(name));

		if (equali(name, nick) || containi(name, nick) != -1)
		{
			matches++;
			matchedPlayer = players[i];
		}
	}

	if (matches == 1)
	{
		status = 0;
		return matchedPlayer;
	}

	status = matches > 1 ? 1 : 2;
	return 0;
}

stock SendPrivateMessage(sender, recipient, const message[])
{
	new senderName[32], senderAuth[35], senderUserid;
	new recipientName[32], recipientAuth[35], recipientUserid;

	GetActorInfo(sender, senderName, charsmax(senderName), senderAuth, charsmax(senderAuth), senderUserid);
	GetActorInfo(recipient, recipientName, charsmax(recipientName), recipientAuth, charsmax(recipientAuth), recipientUserid);

	new recipientLine[CHAT_BUFFER];
	new senderLine[CHAT_BUFFER];

	format(recipientLine, charsmax(recipientLine), "^x04%s ti salje PM: ^x01%s", senderName, message);
	format(senderLine, charsmax(senderLine), "^x04Poslao si PM %s : ^x01%s", recipientName, message);

	SendSayText(recipient, sender, recipientLine);

	if (sender > 0)
	{
		SendSayText(sender, sender, senderLine);
	}
	else
	{
		console_print(sender, "Poslao si PM %s : %s", recipientName, message);
	}

	if (LoggingEnabled())
	{
		log_amx("PM From: ^"%s<%d><%s><>^" To: ^"%s<%d><%s><>^" Message: ^"%s^"", senderName, senderUserid, senderAuth, recipientName, recipientUserid, recipientAuth, message);
		log_message("^"%s<%d><%s><>^" triggered ^"amx_psay^" against ^"%s<%d><%s><>^" (text ^"%s^")", senderName, senderUserid, senderAuth, recipientName, recipientUserid, recipientAuth, message);
	}
}

stock SendAdminMessage(sender, const message[], bool:echoSender)
{
	new senderName[32], senderAuth[35], senderUserid;
	GetActorInfo(sender, senderName, charsmax(senderName), senderAuth, charsmax(senderAuth), senderUserid);

	new line[CHAT_BUFFER];
	format(line, charsmax(line), "^x04%s adminima : %s", senderName, message);

	new players[32], playerCount;
	get_players(players, playerCount, "ch");

	new bool:senderReceived = false;

	for (new i = 0; i < playerCount; i++)
	{
		if (HasAdminChat(players[i]))
		{
			SendSayText(players[i], sender, line);

			if (players[i] == sender)
			{
				senderReceived = true;
			}
		}
	}

	if (echoSender && sender > 0 && !senderReceived)
	{
		SendSayText(sender, sender, line);
	}

	console_print(sender, "%s adminima : %s", senderName, message);
}

stock LogAdminMessage(sender, const message[])
{
	if (!LoggingEnabled())
	{
		return;
	}

	new senderName[32], senderAuth[35], senderUserid;
	GetActorInfo(sender, senderName, charsmax(senderName), senderAuth, charsmax(senderAuth), senderUserid);

	log_amx("ADMINS amx_chat, From: ^"%s<%d><%s><>^" Message: ^"%s^"", senderName, senderUserid, senderAuth, message);
	log_message("^"%s<%d><%s><>^" triggered ^"amx_chat^" (text ^"%s^")", senderName, senderUserid, senderAuth, message);
}

stock SendSayText(recipient, sender, const message[])
{
	if (!recipient || !is_user_connected(recipient) || is_user_bot(recipient))
	{
		return;
	}

	message_begin(MSG_ONE, g_SayText, _, recipient);
	write_byte(sender > 0 ? sender : recipient);
	write_string(message);
	message_end();
}

stock ReportLookupError(id, status)
{
	switch (status)
	{
		case 1:
		{
			ReportError(id, "^x04[KGB]: Greska <Previse igraca sa takvim nickom> / Error <Too many players with that nickname>");
		}
		case 2:
		{
			ReportError(id, "^x04[KGB]: Greska <Nema takvih nick-ova> / Error <No matching players found>");
		}
		default:
		{
			ReportError(id, "^x04[KGB]: Greska <Ne znam, nesto si zajeb'o> / Error <Unknown private-message error>");
		}
	}
}

stock ReportError(id, const message[])
{
	if (id > 0)
	{
		SendSayText(id, id, message);
	}
	else
	{
		console_print(id, "%s", message);
	}
}

stock bool:HasAdminChat(id)
{
	if (id == 0)
	{
		return true;
	}

	return (get_user_flags(id) & ADMIN_CHAT) ? true : false;
}

stock GetActorInfo(id, name[], nameLen, authId[], authIdLen, &userid)
{
	if (id > 0 && is_user_connected(id))
	{
		get_user_name(id, name, nameLen);
		get_user_authid(id, authId, authIdLen);
		userid = get_user_userid(id);
		return;
	}

	copy(name, nameLen, "Console");
	copy(authId, authIdLen, "SERVER");
	userid = 0;
}

stock CreateDefaultConfig()
{
	if (file_exists(CONFIG_FILE))
	{
		return;
	}

	if (!dir_exists(CONFIG_DIR))
	{
		mkdir(CONFIG_DIR);
	}

	new file = fopen(CONFIG_FILE, "wt");
	if (!file)
	{
		server_print("[KGB] Failed to create %s", CONFIG_FILE);
		return;
	}

	fputs(file, "; KGB Admin Color Chat^n");
	fputs(file, "; This file is created automatically and is never overwritten.^n");
	fputs(file, "; Use 1 to enable an option, 0 to disable it.^n");
	fputs(file, "^n");
	fputs(file, "kgb_acc_broadcasts 1^n");
	fputs(file, "kgb_acc_admin_chat 1^n");
	fputs(file, "kgb_acc_private_messages 1^n");
	fputs(file, "kgb_acc_logging 1^n");
	fclose(file);

	server_print("[KGB] Created %s", CONFIG_FILE);
}

stock bool:BroadcastsEnabled()
{
	return get_pcvar_num(g_CvarBroadcasts) ? true : false;
}

stock bool:AdminChatEnabled()
{
	return get_pcvar_num(g_CvarAdminChat) ? true : false;
}

stock bool:PrivateMessagesEnabled()
{
	return get_pcvar_num(g_CvarPrivateMessages) ? true : false;
}

stock bool:LoggingEnabled()
{
	return get_pcvar_num(g_CvarLogging) ? true : false;
}
