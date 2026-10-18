-- Gray is removed from the palette, as it is hard to tell from the neutral UI.
UPDATE labels SET color = 'blue' WHERE color = 'gray';
