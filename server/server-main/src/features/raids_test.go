package features

import (
	"math"
	"server/src/utils/formulas"
	"testing"
	"time"
)

func raidCyclesToDefeatForTest(hp int, defense int, participantAttacks []int) int {
	damagePerCycle := raidPartyCycleDamage(participantAttacks, defense, 1)
	if damagePerCycle <= 0 {
		return 0
	}
	return (hp + damagePerCycle - 1) / damagePerCycle
}

func TestRaidMonsterScaledHPUsesFourPlayerBaseline(t *testing.T) {
	monster := monsterRecord{HP: 4300}

	cases := []struct {
		participants int
		want         int
	}{
		{participants: 4, want: 4300},
		{participants: 3, want: 3870},
		{participants: 2, want: 3440},
		{participants: 1, want: 3010},
		{participants: 0, want: 3010},
	}

	for _, tc := range cases {
		if got := raidMonsterScaledHP(monster, tc.participants); got != tc.want {
			t.Fatalf("participants=%d scaled HP = %d, want %d", tc.participants, got, tc.want)
		}
	}
}

func TestRaidMonsterComingSoonFlagsWyvern(t *testing.T) {
	if !isRaidMonsterComingSoon(monsterRecord{Name: "와이번"}) {
		t.Fatal("wyvern raid should be coming soon")
	}
	if isRaidMonsterComingSoon(monsterRecord{Name: "골렘"}) {
		t.Fatal("golem raid should be available")
	}
}

func TestGolemRaidChapter3FourPlayerAttackCycleTargets(t *testing.T) {
	const (
		golemHP      = 4300
		golemDefense = 45
	)

	cases := []struct {
		name    string
		attacks []int
		want    int
	}{
		{
			name:    "chapter 3-3 rare party needs running pace",
			attacks: []int{91, 115, 103, 78},
			want:    21,
		},
		{
			name:    "chapter 3-5 epic party clears at walking pace",
			attacks: []int{134, 125, 129, 117},
			want:    14,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := raidCyclesToDefeatForTest(golemHP, golemDefense, tc.attacks); got != tc.want {
				t.Fatalf("raid cycles = %d, want %d", got, tc.want)
			}
		})
	}

	rareWalkingCycles := raidCyclesToDefeatForTest(
		golemHP,
		golemDefense,
		[]int{91, 115, 103, 78},
	)
	runningCounterattacks := (rareWalkingCycles + 1) / 2
	if runningCounterattacks != 11 {
		t.Fatalf("chapter 3-3 running counterattacks = %d, want 11", runningCounterattacks)
	}
}

func TestRaidAttackDistanceAppliesPartyAveragedGaugeReduction(t *testing.T) {
	if got := applyBattlePercentToDistance(948, -2.5); math.Abs(got-924.3) > 0.001 {
		t.Fatalf("party attack distance = %.3f, want 924.3", got)
	}
	if got := applyBattlePercentToDistance(948, 0); got != 948 {
		t.Fatalf("base party attack distance = %.3f, want 948", got)
	}
}

func TestRaidMonsterAttackCyclesDueEveryThreeMinutes(t *testing.T) {
	started := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	cases := []struct {
		elapsed   time.Duration
		completed int
		want      int
	}{
		{elapsed: 2*time.Minute + 59*time.Second, completed: 0, want: 0},
		{elapsed: 3 * time.Minute, completed: 0, want: 1},
		{elapsed: 6*time.Minute + 10*time.Second, completed: 1, want: 1},
		{elapsed: 9 * time.Minute, completed: 1, want: 2},
		{elapsed: 3 * time.Minute, completed: 1, want: 0},
	}
	for _, tc := range cases {
		if got := raidMonsterAttackCyclesDue(started.Format(time.RFC3339), started.Add(tc.elapsed), tc.completed); got != tc.want {
			t.Fatalf("elapsed=%s completed=%d due=%d, want %d", tc.elapsed, tc.completed, got, tc.want)
		}
	}
}

func TestRaidMonsterAttackCyclesDueAcceptsPocketBaseTimestamp(t *testing.T) {
	started := time.Date(2026, 7, 22, 11, 11, 44, 0, time.UTC)
	value := "2026-07-22 11:11:44.000Z"
	if got := raidMonsterAttackCyclesDue(value, started.Add(6*time.Minute), 0); got != 2 {
		t.Fatalf("PocketBase timestamp due=%d, want 2", got)
	}
}

func TestGolemRaidChapter33WalkingPartyLosesFragileMembers(t *testing.T) {
	berserkerDamageTaken := formulas.CalculateDamage(115, 42)
	if remaining := 618 - berserkerDamageTaken*8; remaining <= 0 {
		t.Fatalf("berserker HP after 8 counterattacks = %d, want alive", remaining)
	}
	if remaining := 618 - berserkerDamageTaken*9; remaining > 0 {
		t.Fatalf("berserker HP after 9 counterattacks = %d, want defeated", remaining)
	}

	swordsmanDamageTaken := formulas.CalculateDamage(115, 65)
	if remaining := 712 - swordsmanDamageTaken*14; remaining <= 0 {
		t.Fatalf("swordsman HP after 14 counterattacks = %d, want alive", remaining)
	}
	if remaining := 712 - swordsmanDamageTaken*15; remaining > 0 {
		t.Fatalf("swordsman HP after 15 counterattacks = %d, want defeated", remaining)
	}

	epicDamageTaken := formulas.CalculateDamage(115, 98)
	if remaining := 890 - epicDamageTaken*14; remaining <= 0 {
		t.Fatalf("epic character HP after 14 counterattacks = %d, want alive", remaining)
	}
}

func TestRaidPartyCycleDamageCountsEveryParticipantAndCycle(t *testing.T) {
	attacks := []int{75, 85, 95, 105}
	if got := raidPartyCycleDamage(attacks, 24, 2); got != 528 {
		t.Fatalf("two raid cycles damage = %d, want 528", got)
	}
	if got := raidPartyCycleDamage(attacks, 24, 0); got != 0 {
		t.Fatalf("zero raid cycles damage = %d, want 0", got)
	}
}

func TestGolemRaidRewardCoinStaysInsideConfiguredRange(t *testing.T) {
	for range 100 {
		got := randomCoin(2200, 2800)
		if got < 2200 || got > 2800 {
			t.Fatalf("raid reward coin = %d, want 2200..2800", got)
		}
	}
}

func TestRaidWeekStartDateUsesKoreanMonday(t *testing.T) {
	cases := []struct {
		name string
		now  time.Time
		want string
	}{
		{
			name: "monday in korea",
			now:  time.Date(2026, 7, 6, 10, 30, 0, 0, raidWeeklyLocation),
			want: "2026-07-06",
		},
		{
			name: "sunday in korea",
			now:  time.Date(2026, 7, 12, 23, 59, 0, 0, raidWeeklyLocation),
			want: "2026-07-06",
		},
		{
			name: "utc crosses into korea monday",
			now:  time.Date(2026, 7, 5, 16, 0, 0, 0, time.UTC),
			want: "2026-07-06",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := raidWeekStartDate(tc.now); got != tc.want {
				t.Fatalf("raidWeekStartDate() = %s, want %s", got, tc.want)
			}
		})
	}
}
