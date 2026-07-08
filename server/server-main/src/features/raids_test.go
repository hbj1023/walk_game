package features

import (
	"testing"
	"time"
)

func TestRaidMonsterScaledHPUsesFourPlayerBaseline(t *testing.T) {
	monster := monsterRecord{HP: 1800}

	cases := []struct {
		participants int
		want         int
	}{
		{participants: 4, want: 1800},
		{participants: 3, want: 1620},
		{participants: 2, want: 1440},
		{participants: 1, want: 1260},
		{participants: 0, want: 1260},
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
