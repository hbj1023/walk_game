package features

import (
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
	monster := monsterRecord{HP: 4000}

	cases := []struct {
		participants int
		want         int
	}{
		{participants: 4, want: 4000},
		{participants: 3, want: 3600},
		{participants: 2, want: 3200},
		{participants: 1, want: 2800},
		{participants: 0, want: 2800},
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
		golemHP      = 4000
		golemDefense = 24
	)

	cases := []struct {
		name    string
		attacks []int
		want    int
	}{
		{
			name:    "chapter 3-3 party can clear with tight pacing",
			attacks: []int{75, 75, 75, 75},
			want:    20,
		},
		{
			name:    "chapter 3-5 party clears comfortably",
			attacks: []int{95, 95, 95, 95},
			want:    15,
		},
		{
			name:    "mixed chapter 3 party stays inside target range",
			attacks: []int{75, 85, 95, 105},
			want:    16,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := raidCyclesToDefeatForTest(golemHP, golemDefense, tc.attacks); got != tc.want {
				t.Fatalf("raid cycles = %d, want %d", got, tc.want)
			}
		})
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
