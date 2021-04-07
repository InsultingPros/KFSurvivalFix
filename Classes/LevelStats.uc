Class LevelStats extends Object
	Config(KFSurvivalStats)
	PerObjectConfig;

struct FStatEntry
{
	var() config int P,C;
};
var() config array<FStatEntry> ST;
var() config int Best;

defaultproperties
{
}
