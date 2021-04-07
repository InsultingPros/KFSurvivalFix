class SurvivalMessage extends WaitingMessage;

#exec AUDIO IMPORT FILE="Sounds\FinalWaveAlarm.wav" NAME="FinalWaveAlarm" GROUP="Alarm"
#exec AUDIO IMPORT FILE="Sounds\NewWaveAlarm.wav" NAME="NewWaveAlarm" GROUP="Alarm"

var localized string HugeWaveInbound,BossWaveInbound;

static function string GetString(
	optional int Sw,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	switch( Sw )
	{
	case 1:
		return default.WaveInboundMessage;
	case 2:
		return default.WaveInboundMessage;
	case 3:
		return default.FinalWaveInboundMessage;
	case 4:
		return default.WeldedShutMessage;
	case 5:
		return default.ZEDTimeActiveMessage;
	case 6:
		return default.DoorMessage;
	case 7:
		return default.HugeWaveInbound;
	case 8:
		return default.BossWaveInbound;
	}
}

static function int GetFontSize(int Sw, PlayerReplicationInfo RelatedPRI1, PlayerReplicationInfo RelatedPRI2, PlayerReplicationInfo LocalPlayer)
{
	Switch( Sw )
	{
	case 1:
	case 2:
	case 3:
	case 7:
	case 8:
		return 4;
	case 4:
	case 5:
		return 2;
	case 6:
		return 0;
	default:
		return default.FontSize;
	}
}

static function GetPos(int Sw, out EDrawPivot OutDrawPivot, out EStackMode OutStackMode, out float OutPosX, out float OutPosY)
{
	OutDrawPivot = default.DrawPivot;
	OutStackMode = default.StackMode;
	OutPosX = default.PosX;

	switch( Sw )
	{
		case 1:
		case 3:
		case 7:
		case 8:
			OutPosY = 0.45;
			break;
		case 2:
		    OutPosY = 0.4;
		    break;
		case 4:
			OutPosY = 0.7;
		case 5:
			OutPosY = 0.7;
		case 6:
			OutPosY = 0.8;
			break;
	}
}

static function float GetLifeTime(int Sw)
{
	switch( Sw )
	{
		case 1:
		case 3:
			return 1;
		case 2:
		    return 3;
		case 4:
		case 7:
		case 8:
			return 4;
		case 5:
			return 1.5;
		default:
			return 5;
	}
}
static function ClientReceive(
	PlayerController P,
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local Sound S;

	super(CriticalEventPlus).ClientReceive(P, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	if ( Switch==7 )
		S = Sound'NewWaveAlarm';
	else if ( Switch==8 )
		S = Sound'FinalWaveAlarm';
	if( S!=None )
	{
		P.ClientPlaySound(S,true,2.f,SLOT_Interface);
		P.ClientPlaySound(S,true,2.f,SLOT_None);
		P.ClientPlaySound(S,true,2.f,SLOT_Misc);
	}
}

defaultproperties
{
     HugeWaveInbound="HUGE WAVE INBOUND!"
     BossWaveInbound="BOSS WAVE"
}
