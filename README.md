photo-browser-with-ARC-and-storyboard
=====================================

This code comes from a project that I never completed after the client had to back out. 
I needed to store pictures taken by the camera, and 
selected from the camera roll, and store them separately with different customer records.
I had a hard time finding sample code that
demonstrated how to do this using automatic reference counting (ARC) and storyboards. Apple's sample code 
for a photo browser uses the old memory management style and creates the views programmatically. Robert Walker's
Github project PhotoScroller has nice code that updates Apple's project to use ARC, but it still didn't
illustrate how to set up the photo browser using a storyboard. Hopefully this code will give people a starting 
point when they have a need for this type of functionality.
