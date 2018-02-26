//==================================
// Copyright 2018 Playwire LLC.
// The latest version of this code
// can be found at:
// http://github.com/intergi/plugin
//==================================

#include <sourcemod>
#define PLUGIN_VERSION "1.2.1"
enum Game {
  GAME_UNSUPPORTED = -1,
  GAME_CSS,
  GAME_HL2DM,
  GAME_DODS,
  GAME_TF2,
  GAME_L4D,
  GAME_L4D2,
  GAME_ND,
  GAME_CSGO,
  GAME_NMRIH,
  GAME_FOF,
  GAME_ZPS,
  GAME_DAB,
  GAME_GES,
  GAME_HIDDEN,
  GAME_INSURGENCY,
  GAME_BRAINBREAD2,
};
new const String:SUPPORTED_GAMES[Game][] = {
  "cstrike",
  "hl2mp",
  "dod",
  "tf",
  "left4dead",
  "left4dead2",
  "nucleardawn",
  "csgo",
  "nmrih",
  "fof",
  "zps",
  "dab",
  "gesource",
  "hidden",
  "insurgency",
  "brainbread2"
};
new Game:game = GAME_UNSUPPORTED;
new bool:VGUIHooked[MAXPLAYERS+1]
new String:playwire_phoenix_id[128]
new String:playwire_token[128]
new String:playwire_domain_name[128]
new Handle:cv_playwire_phoenix_id;
new Handle:cv_playwire_token;
new Handle:cv_playwire_domain_name;
new Handle:cv_verbose_logging;

public Plugin:myinfo = {
  name        = "Playwire MOTD",
  author      = "Playwire Media",
  description = "Playwire adverts",
  version     = PLUGIN_VERSION,
  url         = "http://www.playwire.com"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
  decl String:game_dir[32];
  GetGameFolderName(game_dir, sizeof(game_dir));
  StringToLower(game_dir);
  for (new i = 0; i < sizeof(SUPPORTED_GAMES); i++)
    if (!strcmp(game_dir, SUPPORTED_GAMES[i])) {
      game = Game:i;
      break;
    }
  if (game == GAME_UNSUPPORTED)
    PrintToServer("phoenix_motd: unsupported game; plugin might not function");
  else
    PrintToServer("phoenix_motd: identified game as %s", SUPPORTED_GAMES[game]);
  return APLRes_Success;
}

public OnPluginStart() {
  new UserMsg:datVGUIMenu = GetUserMessageId("VGUIMenu")
  HookUserMessage(datVGUIMenu, VGUIHook, true)
  AddCommandListener(PageClosed, "closed_htmlpage");
  cv_playwire_phoenix_id  = CreateConVar("playwire_phoenix_id",      "0",                                   "Publisher's Phoenix ID")
  cv_playwire_token       = CreateConVar("playwire_token",           "0",                                   "Publisher's auth token string")
  cv_playwire_domain_name = CreateConVar("playwire_domain_name",     "steam-ad-page-server.herokuapp.com",  "Set domain name")
  cv_verbose_logging      = CreateConVar("playwire_verbose_logging", "0",                                   "Set to 1 to enable verbose logging by plugin")
  AutoExecConfig(true)
}

public OnConfigsExecuted() {
  if (game == GAME_CSGO)
    SetConVarBool(FindConVar("sv_disable_motd"), false);
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen) {
  if (cv_playwire_phoenix_id == INVALID_HANDLE || cv_playwire_token == INVALID_HANDLE || cv_playwire_domain_name == INVALID_HANDLE)
    SetFailState("Could not find a valid config file")
  GetConVarString(cv_playwire_phoenix_id,   playwire_phoenix_id,  sizeof(playwire_phoenix_id))
  GetConVarString(cv_playwire_token,        playwire_token,       sizeof(playwire_token))
  GetConVarString(cv_playwire_domain_name,  playwire_domain_name, sizeof(playwire_domain_name))
  VGUIHooked[client] = false
  return true
}

public Action:VGUIHook(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) {
  new client = players[0]
  if (playersNum > 1 || IsClientInvalid(client) || VGUIHooked[client])
    return Plugin_Continue
  VGUIHooked[client] = true
  CreateTimer(0.1, MOTDHandler, GetClientUserId(client))
  return Plugin_Handled
}

stock bool:IsClientValid(i) {
  if (IsFakeClient(i) || !IsClientConnected(i) || IsClientReplay(i))
    return false
  return true
}

stock bool:IsClientInvalid(i) {
  return !IsClientValid(i)
}

public Action:MOTDHandler(Handle:timer, any:userid)
{
  new client=GetClientOfUserId(userid)
  if(!client || IsClientInvalid(client))
    return Plugin_Stop
  new String:url[255]
  Format(url, sizeof(url), "http://%s/?phoenix_id=%s&token=%s", playwire_domain_name, playwire_phoenix_id, playwire_token)
  DisplayMOTD(client, url)
  return Plugin_Stop
}

public Action:PageClosed(client, const String:command[], argc) {
  if (GetConVarBool(cv_verbose_logging))
    PrintToServer("phoenix_motd: command closed_htmlpage detected");
  if (client && IsClientInGame(client) && game == GAME_CSGO)
    ClientCommand(client, "joingame");
  return Plugin_Handled;
}

stock DisplayMOTD(client, String:url[])
{
  if (IsClientInvalid(client))
    return
  if (GetConVarBool(cv_verbose_logging))
    PrintToServer("phoenix_motd: loading MotD screen");
  new Handle:key_vals = CreateKeyValues("data")
  KvSetString (key_vals, "msg",   url)
  KvSetString (key_vals, "title", "PlugIN! Ad")
  KvSetNum    (key_vals, "type",  MOTDPANEL_TYPE_URL)
  ShowVGUIPanel(client, "info", key_vals, true)
  CloseHandle(key_vals)
}

stock StringToLower(String:input[]) {
  new i = 0, c;
  while ((c = input[i]) != 0) {
    input[i++] = CharToLower(c);
  }
}
