### To update auto icon
1. Modify **`game_name/_icon.json`**.
2. Give the correct hash for the character.  
**You can simply look for it in existing mod's ini file.**  
Usually, VB hash for WuWa, IB hashes for Hoyo games & Endfield.
3. One character can have multiple hashes, it's fine, and it's better.
4. Give image file on corresponding game folder.
5. List the hash and image link in **`game_name/_icon.json`**.
6. **Keep it mind that old character could have their hash changed because game update.**

### Icon rules
1. Max file size is less than 100 KB
2. Icon dimension is 256 x 256 pixels (too small will be blurry in 2x size, too large will use too much RAM)
3. `.webp` or `.png` files

### Pre-requisite
1. Fork the repository.
2. Create new branch.
3. Update/modify that branch.
4. Create Pull Request from that branch.  
5. [More info here](https://github.com/Aglglg/No-Reload-Mod-Manager#repository-contribution)
