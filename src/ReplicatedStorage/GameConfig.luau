local GameConfig = {}

GameConfig.QUEUE_SIZES = {3, 4, 5}
GameConfig.QUEUE_START_DELAY = 3

GameConfig.BUTTON_STOP_SPEED = 1
GameConfig.BUTTON_PRESS_DEPTH = 0.45
GameConfig.BUTTON_TWEEN_TIME = 0.05

GameConfig.WRITE_TIME    = 30
GameConfig.DRAW_TIME     = 60
GameConfig.DESCRIBE_TIME = 25
GameConfig.REVIEW_TIME_PER_ENTRY = 7
GameConfig.RESULTS_TIME  = 15
GameConfig.REWARDS = { [1]=1500, [2]=1000, [3]=600, [4]=250, [5]=100 }
GameConfig.CANVAS_W = 540
GameConfig.CANVAS_H = 410
GameConfig.BRUSH_SIZES = {4, 8, 16}
GameConfig.MAX_DRAW_POINTS = 50000
GameConfig.RETURN_PLACE_ID = 0
GameConfig.MAIN_GUI_NAME = "DrawForSlotsGui"
GameConfig.INTRO_ENABLED = true
GameConfig.TESTING_GIVE_COINS = false
GameConfig.TESTING_COINS_AMOUNT = 1000
GameConfig.UI_REF_W = 1920
GameConfig.UI_REF_H = 1080
GameConfig.UI_SCALE_MIN = 0.5
GameConfig.UI_SCALE_MAX = 1.2
-- R15 KeyframeSequence names in ServerStorage.RBX_ANIMSAVES.Dummy
GameConfig.PODIUM_DANCE_1 = "Take The L"
GameConfig.PODIUM_DANCE_2 = "Ride The Pony"
GameConfig.PODIUM_DANCE_3 = "Pop Lock"
return GameConfig
