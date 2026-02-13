
# Touch Controls(Gameplay not builder mode):

1. Tap on the ball and pull back to aim, aim by sliding your finger up and down to change the angle of the club, pulling back to increase the power of the shot - do both without releasing your finger from the screen
2. Release to hit the ball


In the game UI, down the bottom once you have placed the club you will have an undo button to remove the club and place it again. You can also tap on the club to remove it and place again. A small dot will appear on the tile around the ball to show where the club is going to be placed while you are tapping and holding to aim.


once you have started a swing you cant undo it. when you tap and hold to swing, the ball trajectory will be shown as a dashed line from the ball to wherever you are aiming. The length of the tapandhold from start(tap first location) to release(release point) will determine the power of the shot. 

Players can hit the ball hard enough to go over obstacles.

Remove the hand tracking entirely and remove the need to use the camera in game, the game will be played in portrait mode on the phone. We dont need the camera permission at startup, just load straight to the Main Menu. 

In the settings the hand tracking and kalman filter options, Change the flick power to hit power and make it increase/decrease the power of the shot. remove the max swing power. Keep the settings menu as it is currently rendered it works well just change those things. 

See IMG_6306 the black background circles behind the object menu renders overlap. Not the object render itself but the circle behind it. Remove only those circles behind the object menu renders, Leave the other black circles on the menus as they are. 

See IMG_6307.PNG, the view in game and builder mode is 90degrees rotated, everything should be at a 45degree angle, like how the website is rendered. Rework the camera so the 4 axis rotate on the corner angles of the board, not on the center of the board. Center the camera around the ball position, not the center of the board. 