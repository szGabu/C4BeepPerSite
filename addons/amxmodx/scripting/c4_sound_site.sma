#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <csx>

// ** COMPILER OPTIONS **
// Adjust as needed

// Enable if you want to unprecache the game's stock C4 beeping sounds
// Since beeps will be handled by the plugin these are not needed anymore
// This action will effectively free you up 4 sound resource slots in the server
// However, enabling this will break custom maps and plugins that make use of these  
// By the nature of these sounds it's extremely unlikely though
#define UNPRECACHE_SOUNDS   1

// ** COMPILER OPTIONS END HERE **

#define PLUGIN_NAME         "Different C4 sound per site"
#define PLUGIN_VERSION      "1.0.1"
#define PLUGIN_AUTHOR       "szGabu"

#define MAX_ZONES           3

#define BOMBSITE_A          "#BombsiteA"
#define BOMBSITE_B          "#BombsiteB"
#define BOMBSITE_C          "#BombsiteC"

#define BEEP_SOUND_1        "weapons/c4_beep1.wav" 
#define BEEP_SOUND_2        "weapons/c4_beep2.wav" 
#define BEEP_SOUND_3        "weapons/c4_beep3.wav" 
#define BEEP_SOUND_4        "weapons/c4_beep4.wav" 
#define BEEP_SOUND_5        "weapons/c4_beep5.wav"

#define BEEP_SOUND_FILE     "weapons/c4_generic_beep1.wav"
#define BEEP_SOUND_TASK     654197
#define BEEP_CYCLE_RATE     1.5

#define SND_DO_NOT_HOOK     256

#if AMXX_VERSION_NUM < 183
#define MAX_PLAYERS         32
#define MAX_NAME_LENGTH     32

new g_cvarPluginEnabled;
#endif

new bool:g_bPluginEnabled = false;
new g_iPluginFlags;

new g_iBombZones[MAX_ZONES] = { 0, ... };
new g_szLastNavZone[MAX_PLAYERS+1][MAX_NAME_LENGTH];
new g_iBombPlantedOnSite = -1;
new g_iBombBeepState = -1;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
    register_message(get_user_msgid("Location"), "Message_UserLocation");
    register_event("HLTV", "Event_RoundStart", "a", "1=0", "2=0");

    register_forward(FM_EmitSound, "Event_EmitSound");

    #if AMXX_VERSION_NUM < 183
    g_cvarPluginEnabled = register_cvar("amx_c4ptc_enabled", "1");
    #else 
    bind_pcvar_num(create_cvar("amx_c4ptc_enabled", "1", FCVAR_NONE, "Enables the Plugin", true, 0.0, true, 1.0), g_bPluginEnabled);
    AutoExecConfig();
    #endif

    g_iPluginFlags = plugin_flags();
}

#if AMXX_VERSION_NUM < 183
public plugin_cfg()
{
    g_bPluginEnabled = get_pcvar_num(g_cvarPluginEnabled) == 1;
}
#else
public OnConfigsExecuted() 
{
    create_cvar("amx_c4ptc_version", PLUGIN_VERSION, FCVAR_SERVER); 
    // creating it here prevents it from getting added to the exec config file
    // sourcemod uses FCVAR_DONTRECORD to not writing it but unsure what AMXX uses
}
#endif

public plugin_precache()
{
    #if UNPRECACHE_SOUNDS > 0
    register_forward(FM_PrecacheSound, "Forward_PrecacheSound")
    #endif
    precache_sound(BEEP_SOUND_FILE);
}

#if UNPRECACHE_SOUNDS > 0
public Forward_PrecacheSound(szSound[])
{
    if(equali(BEEP_SOUND_1, szSound) || 
        equali(BEEP_SOUND_2, szSound) || 
        equali(BEEP_SOUND_3, szSound) || 
        equali(BEEP_SOUND_4, szSound) || 
        equali(BEEP_SOUND_5, szSound))
    {
        forward_return(FMV_CELL, 0)
        return FMRES_SUPERCEDE
    }

    return FMRES_IGNORED;
}  
#endif

public Event_RoundStart()
{
    DetectSites();
    g_iBombPlantedOnSite = -1;
    g_iBombBeepState = -1;

    //returning on these values should fix #1 but deleting the task wouldn't hurt
    if(task_exists(BEEP_SOUND_TASK))
        remove_task(BEEP_SOUND_TASK);
}

public Event_EmitSound(iEnt, iChannel, const szSample[], Float:fVolume, Float:fAttenuation, iFlags, iPitch)
{
    if(g_bPluginEnabled && containi(szSample, "c4_beep") >= 0 && iFlags ^ SND_DO_NOT_HOOK)
    {
        new Float:aData[5];
        aData[0] = iEnt*1.0;
        aData[1] = iChannel*1.0;
        aData[2] = fVolume;
        aData[3] = iFlags*1.0;
        aData[4] = (iPitch-(5*g_iBombPlantedOnSite))*1.0;

        if(equali(szSample, BEEP_SOUND_1))
            g_iBombBeepState = 1;
        if(equali(szSample, BEEP_SOUND_2))
            g_iBombBeepState = 2;
        else if(equali(szSample, BEEP_SOUND_3))
            g_iBombBeepState = 3;
        else if(equali(szSample, BEEP_SOUND_4))
            g_iBombBeepState = 5;
        else if(equali(szSample, BEEP_SOUND_5))
            g_iBombBeepState = 8;

        if(!task_exists(BEEP_SOUND_TASK))
        #if AMXX_VERSION_NUM >= 183
            set_task(BEEP_CYCLE_RATE, "PlayBeepingSound", BEEP_SOUND_TASK, aData, sizeof aData);    
        #else
            set_task(BEEP_CYCLE_RATE, "PlayBeepingSound", BEEP_SOUND_TASK, _:aData, sizeof aData);     
        #endif 
            
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public PlayBeepingSound(Float:aData[5], iTaskId)
{
    if(g_iBombPlantedOnSite == -1 || g_iBombBeepState == -1)
        return;

    new iEnt = floatround(aData[0]);

    if(pev_valid(iEnt) == 0)
        return;

    new iChannel = floatround(aData[1]);
    new Float:fVolume = aData[2];
    new iFlags = floatround(aData[3]);
    new iPitch = floatround(aData[4]);

    new Float:fAttenuation = 0.0;

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] c4_sound_site.amxx::PlayBeepingSound() - Playing at %f attenuation", fAttenuation);

    switch(g_iBombBeepState)
    {
        case 1:
        {
            fAttenuation = 1.5;
		}
		case 2:
        {
			fAttenuation = 1.0;
		}
		case 3:
        {
			fAttenuation = 0.8;
		}
		case 5:
        {
			fAttenuation = 0.5;
		}
		case 8:
        {
			fAttenuation = 0.2;
        }
    }
        
    emit_sound(iEnt, iChannel, BEEP_SOUND_FILE, fVolume, fAttenuation, iFlags | SND_DO_NOT_HOOK, iPitch)

    #if AMXX_VERSION_NUM >= 183 
    set_task(g_iBombBeepState ? BEEP_CYCLE_RATE/g_iBombBeepState : BEEP_CYCLE_RATE, "PlayBeepingSound", BEEP_SOUND_TASK, aData, sizeof aData);  
    #else
    set_task(g_iBombBeepState ? BEEP_CYCLE_RATE/g_iBombBeepState : BEEP_CYCLE_RATE, "PlayBeepingSound", BEEP_SOUND_TASK, _:aData, sizeof aData);   
    #endif  
}

DetectSites()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] c4_sound_site.amxx::DetectSites() - called.");

    new iEnt = -1
    new iCursor = 0;
    while((iEnt = find_ent_by_class(iEnt, "func_bomb_target")))
    {
        if(MAX_ZONES > iCursor)
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] c4_sound_site.amxx::DetectSites() - g_iBombZones[%d] is now %d", iCursor, iEnt);

            g_iBombZones[iCursor++] = iEnt;
        }
    }

    while((iEnt = find_ent_by_class(iEnt, "info_bomb_target")))
    {
        if(MAX_ZONES > iCursor)
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] c4_sound_site.amxx::DetectSites() - g_iBombZones[%d] is now %d", iCursor, iEnt);

            g_iBombZones[iCursor++] = iEnt;
        }
    }
}

public Message_UserLocation()
{
    new iClient = get_msg_arg_int(1);
    get_msg_arg_string(2, g_szLastNavZone[iClient], charsmax(g_szLastNavZone));
}

public bomb_planted(iClient)
{
    if(containi(g_szLastNavZone[iClient], "#Bombsite") != -1)
    {
        if(equali(BOMBSITE_A, g_szLastNavZone[iClient]))
        {
            g_iBombPlantedOnSite = 0;
            return;
        }
        else if(equali(BOMBSITE_B, g_szLastNavZone[iClient]))
        {
            g_iBombPlantedOnSite = 1;
            return;
        }
        else if(equali(BOMBSITE_C, g_szLastNavZone[iClient]))
        {
            g_iBombPlantedOnSite = 2;
            return;
        }
    }

    //get nearest
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - Fallback by entity");

    new iEnt = -1;
    new iDesiredSite = -1;
    new Float:fCurrentDist = 99999.9;
    new Float:fClientPos[3], Float:fSitePos[3];
    pev(iClient, pev_origin, fClientPos);
    while((iEnt = find_ent_by_class(iEnt, "func_bomb_target")))
    {
        get_brush_entity_origin(iEnt, fSitePos);
        new Float:fTempDist = get_distance_f(fClientPos, fSitePos);

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - Distance between %d and %d is %f", iClient, iEnt, fTempDist);
            server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - Stored distance %f", fCurrentDist);
        }

        if(fCurrentDist > fTempDist)
        {
            fCurrentDist = fTempDist;
            iDesiredSite = iEnt;
        }
    }

    while((iEnt = find_ent_by_class(iEnt, "info_bomb_target")))
    {
        pev(iEnt, pev_origin, fSitePos);
        new Float:fTempDist = get_distance_f(fClientPos, fSitePos);

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - Distance between %d and %d is %f", iClient, iEnt, fTempDist);
            server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - Stored distance %f", fCurrentDist);
        }

        if(fCurrentDist > fTempDist)
        {
            fCurrentDist = fTempDist;
            iDesiredSite = iEnt;
        }
    }

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - iDesiredSite is %d", iDesiredSite);

    for(new iCursor = 0; iCursor < MAX_ZONES; iCursor++)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] c4_sound_site.amxx::bomb_planted() - g_iBombZones[%d] is %d", iCursor, g_iBombZones[iCursor]);

        if(g_iBombZones[iCursor] == iDesiredSite)
        {
            g_iBombPlantedOnSite = iCursor;
            break;
        }
    }

    if(g_iBombPlantedOnSite == -1)
        g_iBombPlantedOnSite = 0; //fallback in case of error
}

public bomb_defused(iClient)
{
    if(task_exists(BEEP_SOUND_TASK))
        remove_task(BEEP_SOUND_TASK);
}

public bomb_explode(iPlanter, iDefuser)
{
    if(task_exists(BEEP_SOUND_TASK))
        remove_task(BEEP_SOUND_TASK);
}