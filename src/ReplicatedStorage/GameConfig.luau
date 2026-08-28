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
GameConfig.DRAW_COLORS = {
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 90, 90),
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 220, 40),
	Color3.fromRGB(50, 200, 50),
	Color3.fromRGB(20, 90, 45),
	Color3.fromRGB(50, 100, 255),
	Color3.fromRGB(20, 40, 140),
	Color3.fromRGB(160, 50, 255),
	Color3.fromRGB(0, 220, 200),
	Color3.fromRGB(255, 80, 180),
	Color3.fromRGB(150, 90, 50),
	Color3.fromRGB(255, 200, 160),
	Color3.fromRGB(255, 200, 220),
}
GameConfig.COLOR_EQUIP_RING = Color3.fromRGB(255, 210, 40)
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
GameConfig.PODIUM_DANCE_2 = "Hype"
GameConfig.PODIUM_DANCE_3 = "Pop Lock"
return GameConfig
