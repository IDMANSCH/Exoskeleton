# High-level exercise intent. Never contains PWM, torque, or motor timing.
uint32 sequence
string session_id
string plan_item_id
string exercise_code
uint8 ACTION_START=0
uint8 ACTION_PAUSE=1
uint8 ACTION_STOP=2
uint8 action
uint8 SIDE_BOTH=0
uint8 SIDE_LEFT=1
uint8 SIDE_RIGHT=2
uint8 side
uint16 repetitions
uint16 sets
float32 assist_percent
