# NPC Default Dialogue
@id: npc_default
@speaker: Wastelander
@start: intro

## intro
Keep your voice down. The dunes carry sound farther than you'd think.
- Who are you? -> who
- Any work around here? -> work
- [Speech 25] Tell me what you're not saying. -> speech_pass | check_skill=speech | check_skill_min=25 | next_on_fail=speech_fail
- Goodbye. -> END

## who
Name's Harker. I keep this camp supplied and mostly alive.
- Back. -> intro

## work
Water pumps keep failing. If you can bring me spare seals, we can talk payment.
- I'll take the job. -> job_accepted | set_fact=quest_water_started | add_faction_rep=settlers:1
- Not interested. -> intro

## job_accepted
Good. Bring back three seal rings and don't get buried out there.
- I'll be back. -> END

## speech_pass
Fine. Raiders are using the old refinery at dusk. I never told you that.
- I appreciate it. -> intro | set_fact=learned_refinery_secret | add_skill=speech:1

## speech_fail
You're not half as subtle as you think.
- Back. -> intro
