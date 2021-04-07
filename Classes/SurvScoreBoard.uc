class SurvScoreBoard extends KFScoreBoard;

var localized string NotShownInfo,PlayerCountText,SpectatorCountText,AliveCountText,BotText,LevelText,TopScoresText,RankInfoText;
var string RenderTopScoresInfo;
var bool bHasInit;

simulated final function InitInfoStr()
{
	local byte i;
	local string Key;
	local PlayerController PC;

	PC = Level.GetLocalPlayerController();
	for ( i=0; i<255; i++ )
	{
		Key = PC.ConsoleCommand("KEYNAME "$i);
		if( Key!="" && PC.ConsoleCommand("KEYBINDING "$Key)~="Walking" )
			break;
	}
	if( i==255 )
		Key = "Walk";

	RenderTopScoresInfo = RankInfoText;
	ReplaceText(RenderTopScoresInfo,"%w",Key);
}
simulated function UpdateScoreBoard(Canvas Canvas)
{
	if( !bHasInit )
	{
		InitInfoStr();
		bHasInit = true;
	}
	if( Canvas.Viewport.Actor.bRun==0 )
		RenderScores(Canvas);
	else RenderRanks(Canvas);
}
simulated final function float RenderHeader( Canvas Canvas, int PLCount, int SpecCount, int AliveCount )
{
	local string S;
	local float ResY,YL;

	Canvas.Font = class'ROHud'.static.GetSmallMenuFont(Canvas);
	Canvas.TextSize("ABC",ResY,YL);
	ResY = Canvas.ClipY * 0.08;
	Canvas.bCenter = true;
	
	Canvas.Style = ERenderStyle.STY_Normal;
	
	// First line, server name
	if( Level.NetMode!=NM_StandAlone )
	{
		Canvas.DrawColor = HUDClass.default.WhiteColor;
		Canvas.SetPos(0,ResY-YL);
		Canvas.DrawText(GRI.ServerName,false);
	}

	// Second line, game info
	Canvas.DrawColor = HUDClass.default.RedColor;
	if( InvasionGameReplicationInfo(GRI)==None )
		S = "Title Error";
	else S = SkillLevel[Clamp(InvasionGameReplicationInfo(GRI).BaseDifficulty, 0, 7)] @ "|" @ WaveString @ (InvasionGameReplicationInfo(GRI).WaveNumber + 1) @ "|" @ Level.Title @ "|" @ FormatTime(GRI.ElapsedTime);
	Canvas.SetPos(0,ResY);
	Canvas.DrawText(S,false);
	ResY+=YL;
	
	// Third line, player count
	S = PlayerCountText@PLCount@SpectatorCountText@SpecCount@AliveCountText@AliveCount;
	Canvas.SetPos(0,ResY);
	Canvas.DrawText(S,false);
	ResY+=YL;
	
	// Final line, top scores info
	Canvas.DrawColor = HUDClass.default.GoldColor;
	Canvas.SetPos(0,ResY);
	Canvas.DrawText(RenderTopScoresInfo,false);
	ResY+=YL;

	Canvas.bCenter = false;
	return ResY+(YL*2.f);
}
simulated final function RenderRanks(Canvas Canvas)
{
	local SurvPRI PRI;
	local PlayerReplicationInfo PR;
	local int i,EntriesCount,NotShownCount,FontReduction;
	local float XL,YL,PlayerBoxSizeY,BoxSpaceY,HeaderOffsetY,BoxWidth,PosXPos,NameXPos,ScoreXPos,BoxXPos,TitleYPos,BoxTextOffsetY;
	local string S;

	PRI = SurvPRI(Controller(Owner).PlayerReplicationInfo);
	if( PRI==none )
		return;

	for ( i = 0; i < GRI.PRIArray.Length; i++)
	{
		PR = GRI.PRIArray[i];
		if ( !PR.bOnlySpectator )
		{
			if( !PR.bOutOfLives && KFPlayerReplicationInfo(PR).PlayerHealth>0 )
				++EntriesCount;
			NotShownCount++;
		}
		else ++FontReduction;
	}

	// First, draw title.
	HeaderOffsetY = RenderHeader(Canvas,NotShownCount,FontReduction,EntriesCount);

	// Select best font size and box size to fit as many players as possible on screen
	if ( Canvas.ClipX < 600 )
		i = 4;
	else if ( Canvas.ClipX < 800 )
		i = 3;
	else if ( Canvas.ClipX < 1000 )
		i = 2;
	else if ( Canvas.ClipX < 1200 )
		i = 1;
	else i = 0;

	Canvas.Font = class'ROHud'.static.LoadMenuFontStatic(i);
	Canvas.TextSize("Test", XL, YL);
	PlayerBoxSizeY = 1.2 * YL;
	BoxSpaceY = 0.25 * YL;
	EntriesCount = PRI.TopPlayers.Length;
	FontReduction = 0;

	while( ((PlayerBoxSizeY+BoxSpaceY)*EntriesCount)>(Canvas.ClipY-HeaderOffsetY) )
	{
		if( ++i>=5 || ++FontReduction>=3 ) // Shrink font, if too small then break loop.
		{
			// We need to remove some player names here to make it fit.
			NotShownCount = EntriesCount-int((Canvas.ClipY-HeaderOffsetY)/(PlayerBoxSizeY+BoxSpaceY));
			EntriesCount-=NotShownCount;
			break;
		}
		Canvas.Font = class'ROHud'.static.LoadMenuFontStatic(i);
		Canvas.TextSize("Test", XL, YL);
		PlayerBoxSizeY = 1.2 * YL;
		BoxSpaceY = 0.25 * YL;
	}

	BoxWidth = 0.9 * Canvas.ClipX;
	BoxXPos = 0.5 * (Canvas.ClipX - BoxWidth);
	PosXPos = BoxXPos + 0.01 * BoxWidth;
	NameXPos = BoxXPos + 0.1 * BoxWidth;
	ScoreXPos = BoxXPos + 0.9 * BoxWidth;

	// draw background boxes
	Canvas.Style = ERenderStyle.STY_Alpha;
	Canvas.DrawColor = HUDClass.default.WhiteColor;
	Canvas.DrawColor.A = 128;

	for ( i = 0; i < EntriesCount; i++ )
	{
		Canvas.SetPos(BoxXPos, HeaderOffsetY + (PlayerBoxSizeY + BoxSpaceY) * i);
		Canvas.DrawTileStretched( BoxMaterial, BoxWidth, PlayerBoxSizeY);
	}

	// Draw headers
	TitleYPos = HeaderOffsetY - 1.1 * YL;

	Canvas.DrawColor = HUDClass.default.WhiteColor;
	Canvas.SetPos(NameXPos, TitleYPos);
	Canvas.DrawTextClipped(PlayerText);

	Canvas.TextSize(TopScoresText, XL, YL);
	Canvas.SetPos(ScoreXPos - 0.5 * XL, TitleYPos);
	Canvas.DrawTextClipped(TopScoresText);

	Canvas.SetPos(PosXPos, TitleYPos);
	Canvas.DrawTextClipped(RankText);

	BoxTextOffsetY = HeaderOffsetY + 0.5 * (PlayerBoxSizeY - YL);

	Canvas.DrawColor = HUDClass.default.WhiteColor;
	Canvas.Style = ERenderStyle.STY_Normal;

	// Draw the player informations.
	NotShownCount = 0;
	for ( i = 0; i < EntriesCount; i++ )
	{
		if( i>0 && PRI.TopPlayers[i].Score!=PRI.TopPlayers[i-1].Score )
			NotShownCount = i;

		// Draw rank
		Canvas.DrawColor = HUDClass.default.GoldColor;
		Canvas.SetPos(PosXPos, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
		Canvas.DrawTextClipped("#"$string(NotShownCount+1),true);

		// Draw name
		Canvas.DrawColor = HUDClass.default.WhiteColor;
		Canvas.SetPos(NameXPos, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
		Canvas.DrawTextClipped(PRI.TopPlayers[i].Player,true);
		
		// Draw score
		S = string(PRI.TopPlayers[i].Score);
		Canvas.TextSize(S, XL, YL);
		Canvas.SetPos(ScoreXPos-XL*0.5f, (PlayerBoxSizeY + BoxSpaceY)*i + BoxTextOffsetY);
		Canvas.DrawTextClipped(S,true);
	}
}
simulated final function RenderScores(Canvas Canvas)
{
	local PlayerReplicationInfo PRI, OwnerPRI;
	local int i, Stars, FontReduction, NetXPos, PlayerCount, HeaderOffsetY, HeadFoot, MessageFoot, PlayerBoxSizeY, BoxSpaceY, NameXPos, BoxTextOffsetY, OwnerOffset, HealthXPos, BoxXPos,KillsXPos, TitleYPos, BoxWidth, VetXPos, NotShownCount;
	local float XL,YL;
	local float deathsXL, KillsXL, NetXL, HealthXL, MaxNamePos, KillWidthX, CashXPos, TimeXPos, WavesXPos;
	local Material VeterancyBox;
	local string S;

	OwnerPRI = KFPlayerController(Owner).PlayerReplicationInfo;
	OwnerOffset = -1;

	for ( i = 0; i < GRI.PRIArray.Length; i++)
	{
		PRI = GRI.PRIArray[i];
		if ( !PRI.bOnlySpectator )
		{
			if( !PRI.bOutOfLives && KFPlayerReplicationInfo(PRI).PlayerHealth>0 )
				++HeadFoot;
			if ( PRI == OwnerPRI )
				OwnerOffset = i;
			PlayerCount++;
		}
		else ++NetXPos;
	}

	// First, draw title.
	HeaderOffsetY = RenderHeader(Canvas,PlayerCount,NetXPos,HeadFoot);

	// Select best font size and box size to fit as many players as possible on screen
	if ( Canvas.ClipX < 600 )
		i = 4;
	else if ( Canvas.ClipX < 800 )
		i = 3;
	else if ( Canvas.ClipX < 1000 )
		i = 2;
	else if ( Canvas.ClipX < 1200 )
		i = 1;
	else i = 0;

	Canvas.Font = class'ROHud'.static.LoadMenuFontStatic(i);
	Canvas.TextSize("Test", XL, YL);
	PlayerBoxSizeY = 1.2 * YL;
	BoxSpaceY = 0.25 * YL;

	while( ((PlayerBoxSizeY+BoxSpaceY)*PlayerCount)>(Canvas.ClipY-HeaderOffsetY) )
	{
		if( ++i>=5 || ++FontReduction>=3 ) // Shrink font, if too small then break loop.
		{
			// We need to remove some player names here to make it fit.
			NotShownCount = PlayerCount-int((Canvas.ClipY-HeaderOffsetY)/(PlayerBoxSizeY+BoxSpaceY))+1;
			PlayerCount-=NotShownCount;
			break;
		}
		Canvas.Font = class'ROHud'.static.LoadMenuFontStatic(i);
		Canvas.TextSize("Test", XL, YL);
		PlayerBoxSizeY = 1.2 * YL;
		BoxSpaceY = 0.25 * YL;
	}

	HeadFoot = 7 * YL;
	MessageFoot = 1.5 * HeadFoot;

	BoxWidth = 0.85 * Canvas.ClipX;
	BoxXPos = 0.475 * (Canvas.ClipX - BoxWidth);
	// BoxWidth = Canvas.ClipX - 2 * BoxXPos;
	VetXPos = BoxXPos + 0.0001 * BoxWidth;
	NameXPos = VetXPos + PlayerBoxSizeY*1.75f;
	KillsXPos = BoxXPos + 0.45 * BoxWidth;
	WavesXPos = BoxXPos + 0.55 * BoxWidth;
	CashXPos = BoxXPos + 0.65 * BoxWidth;
	HealthXpos = BoxXPos + 0.75 * BoxWidth;
	TimeXPos = BoxXPos + 0.87 * BoxWidth;
	NetXPos = BoxXPos + 0.996 * BoxWidth;

	// draw background boxes
	Canvas.Style = ERenderStyle.STY_Alpha;
	Canvas.DrawColor = HUDClass.default.WhiteColor;
	Canvas.DrawColor.A = 128;

	for ( i = 0; i < PlayerCount; i++ )
	{
		Canvas.SetPos(BoxXPos, HeaderOffsetY + (PlayerBoxSizeY + BoxSpaceY) * i);
		Canvas.DrawTileStretched( BoxMaterial, BoxWidth, PlayerBoxSizeY);
	}
	if( NotShownCount>0 ) // Add box for not shown players.
	{
		Canvas.DrawColor = HUDClass.default.RedColor;
		Canvas.SetPos(BoxXPos, HeaderOffsetY + (PlayerBoxSizeY + BoxSpaceY) * PlayerCount);
		Canvas.DrawTileStretched( BoxMaterial, BoxWidth, PlayerBoxSizeY);
	}

	// Draw headers
	TitleYPos = HeaderOffsetY - 1.1 * YL;
	Canvas.TextSize(HealthText, HealthXL, YL);
	Canvas.TextSize(DeathsText, DeathsXL, YL);
	Canvas.TextSize(KillsText, KillsXL, YL);
	Canvas.TextSize(NetText, NetXL, YL);

	Canvas.DrawColor = HUDClass.default.WhiteColor;
	Canvas.SetPos(NameXPos, TitleYPos);
	Canvas.DrawTextClipped(PlayerText);

	Canvas.SetPos(KillsXPos - 0.5 * KillsXL, TitleYPos);
	Canvas.DrawTextClipped(KillsText);
	
	Canvas.TextSize(LevelText, KillsXL, YL);
	Canvas.SetPos(WavesXPos - 0.5 * KillsXL, TitleYPos);
	Canvas.DrawTextClipped(LevelText);

	Canvas.TextSize(PointsText, XL, YL);
	Canvas.SetPos(CashXPos - 0.5 * XL, TitleYPos);
	Canvas.DrawTextClipped(PointsText);

	Canvas.TextSize(TimeText, XL, YL);
	Canvas.SetPos(TimeXPos - 0.5 * XL, TitleYPos);
	Canvas.DrawTextClipped(TimeText);

	Canvas.SetPos(HealthXPos - 0.5 * HealthXL, TitleYPos);
	Canvas.DrawTextClipped(HealthText);

	Canvas.SetPos(NetXPos - NetXL, TitleYPos);
	Canvas.DrawTextClipped(NetText);
	
	Canvas.TextSize(RankText, XL, YL);
	Canvas.SetPos((BoxXPos-XL)*0.5, TitleYPos);
	Canvas.DrawTextClipped(RankText);

	BoxTextOffsetY = HeaderOffsetY + 0.5 * (PlayerBoxSizeY - YL);

	MaxNamePos = Canvas.ClipX;
	Canvas.ClipX = KillsXPos - 4.f;

	for ( i = 0; i < PlayerCount; i++ )
	{
		Canvas.SetPos(NameXPos, (PlayerBoxSizeY + BoxSpaceY)*i + BoxTextOffsetY);
		if( i == OwnerOffset )
		{
			Canvas.DrawColor.G = 0;
			Canvas.DrawColor.B = 0;
		}
		else
		{
			Canvas.DrawColor.G = 255;
			Canvas.DrawColor.B = 255;
		}
		Canvas.DrawTextClipped(GRI.PRIArray[i].PlayerName);
	}
	if( NotShownCount>0 ) // Draw not shown info
	{
		Canvas.DrawColor.G = 255;
		Canvas.DrawColor.B = 0;
		Canvas.SetPos(NameXPos, (PlayerBoxSizeY + BoxSpaceY)*PlayerCount + BoxTextOffsetY);
		Canvas.DrawText(NotShownCount@NotShownInfo,true);
	}

	Canvas.ClipX = MaxNamePos;
	Canvas.DrawColor = HUDClass.default.WhiteColor;

	Canvas.Style = ERenderStyle.STY_Normal;

	// Draw the player informations.
	for ( i = 0; i < PlayerCount; i++ )
	{
		PRI = GRI.PRIArray[i];
		Canvas.DrawColor = HUDClass.default.WhiteColor;

		// Display perks.
		if ( KFPlayerReplicationInfo(PRI)!=None && KFPlayerReplicationInfo(PRI).ClientVeteranSkill!=none )
		{
			Stars = KFPlayerReplicationInfo(PRI).ClientVeteranSkillLevel;
			if( Stars<=5 )
				VeterancyBox = KFPlayerReplicationInfo(PRI).ClientVeteranSkill.Default.OnHUDIcon;
			else VeterancyBox = KFPlayerReplicationInfo(PRI).ClientVeteranSkill.Default.OnHUDGoldIcon;

			if ( VeterancyBox != None )
				DrawPerkWithStars(Canvas,VetXPos,HeaderOffsetY+(PlayerBoxSizeY+BoxSpaceY)*i,PlayerBoxSizeY,Stars,VeterancyBox);
			Canvas.DrawColor = HUDClass.default.WhiteColor;
		}

		// draw kills
		Canvas.TextSize(KFPlayerReplicationInfo(PRI).Kills, KillWidthX, YL);
		Canvas.SetPos(KillsXPos - 0.5 * KillWidthX, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
		Canvas.DrawText(KFPlayerReplicationInfo(PRI).Kills,true);
		
		// draw waves survived
		if( SurvPRI(PRI)!=None )
		{
			S = string(SurvPRI(PRI).SurvivedWaves)$"/"$string(SurvPRI(PRI).BestSurvivedWaves);
			Canvas.TextSize(S, KillWidthX, YL);
			Canvas.SetPos(WavesXPos - 0.5 * KillWidthX, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
			Canvas.DrawText(S,true);
		}

		// draw cash
		S = string(int(PRI.Score));
		Canvas.TextSize(S, XL, YL);
		Canvas.SetPos(CashXPos-XL*0.5f, (PlayerBoxSizeY + BoxSpaceY)*i + BoxTextOffsetY);
		Canvas.DrawText(S,true);

		// draw time
		if( GRI.ElapsedTime<PRI.StartTime ) // Login timer error, fix it.
			GRI.ElapsedTime = PRI.StartTime;
		S = FormatTime(GRI.ElapsedTime-PRI.StartTime);
		Canvas.TextSize(S, XL, YL);
		Canvas.SetPos(TimeXPos-XL*0.5f, (PlayerBoxSizeY + BoxSpaceY)*i + BoxTextOffsetY);
		Canvas.DrawText(S,true);

		// Draw ping
		if( PRI.bAdmin )
		{
			Canvas.DrawColor = HUDClass.default.RedColor;
			S = AdminText;
		}
		else if ( !GRI.bMatchHasBegun )
		{
			if ( PRI.bReadyToPlay )
				S = ReadyText;
			else S = NotReadyText;
		}
		else if( !PRI.bBot )
			S = string(PRI.Ping*4);
		else S = BotText;
		Canvas.TextSize(S, XL, YL);
		Canvas.SetPos(NetXPos-XL, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
		Canvas.DrawTextClipped(S);

		// draw healths
		if ( PRI.bOutOfLives || KFPlayerReplicationInfo(PRI).PlayerHealth<=0 )
		{
			Canvas.DrawColor = HUDClass.default.RedColor;
			S = OutText;
		}
		else
		{
			if( KFPlayerReplicationInfo(PRI).PlayerHealth>=90 )
				Canvas.DrawColor = HUDClass.default.GreenColor;
			else if( KFPlayerReplicationInfo(PRI).PlayerHealth>=50 )
				Canvas.DrawColor = HUDClass.default.GoldColor;
			else Canvas.DrawColor = HUDClass.default.RedColor;
			S = KFPlayerReplicationInfo(PRI).PlayerHealth@HealthyString;
		}
		Canvas.TextSize(S, XL, YL);
		Canvas.SetPos(HealthXpos - 0.5 * XL, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
		Canvas.DrawTextClipped(S);
		
		// Draw rank
		if( SurvPRI(PRI)!=None && SurvPRI(PRI).PlayerRank>=0 )
		{
			Canvas.DrawColor = HUDClass.default.GoldColor;
			S = "#"$(SurvPRI(PRI).PlayerRank+1);
			Canvas.TextSize(S, XL, YL);
			Canvas.SetPos((BoxXPos-XL)*0.5, (PlayerBoxSizeY + BoxSpaceY) * i + BoxTextOffsetY);
			Canvas.DrawTextClipped(S);
		}
	}
}

simulated final function DrawPerkWithStars( Canvas C, float X, float Y, float Scale, int Stars, Material PerkIcon )
{
	local byte i;
	local Material StarIcon;

	if( Stars<=5 )
		StarIcon = Class'HudKillingFloor'.Default.VetStarMaterial;
	else
	{
		StarIcon = Class'HudKillingFloor'.Default.VetStarGoldMaterial;
		Stars = Min(Stars-5,5);
	}
	C.SetPos(X,Y);
	C.DrawTile(PerkIcon, Scale, Scale, 0, 0, PerkIcon.MaterialUSize(), PerkIcon.MaterialVSize());
	Y+=Scale*0.9f;
	X+=Scale*0.8f;
	Scale*=0.2f;

	for( i=1; i<=Stars; ++i )
	{
		C.SetPos(X,Y-(i*Scale*0.8f));
		C.DrawTile(StarIcon, Scale, Scale, 0, 0, StarIcon.MaterialUSize(), StarIcon.MaterialVSize());
	}
}

defaultproperties
{
     NotShownInfo="player names not shown"
     PlayerCountText="Players:"
     SpectatorCountText="| Spectators:"
     AliveCountText="| Alive players:"
     BotText="BOT"
     LevelText="Waves/Best"
     TopScoresText="Score"
     RankInfoText="Hold down [%w] key to view top player ranks."
     HealthyString="HP"
     RankText="Rank"
     TimeText="Time"
}
