--[[Author informations]]--
SWEP.Author = "Zaratusa"
SWEP.Contact = "http://steamcommunity.com/profiles/76561198032479768"

if SERVER then
	AddCSLuaFile()

	resource.AddWorkshop("1398388611")
else
	LANG.AddToLanguage("English", "golden_deagle_name", "Golden Deagle")
	LANG.AddToLanguage("English", "golden_deagle_desc", "Shoot a player in another team, kill the player.\nShoot a team mate, kill yourself.\nBe careful!")

	LANG.AddToLanguage("Deutsch", "golden_deagle_name", "Goldene Deagle")
	LANG.AddToLanguage("Deutsch", "golden_deagle_desc", "Schieße auf einen Spieler eines anderen Teams, um ihn direkt zu töten.\nSchieße auf deine Mates, um dich selbst zu töten.\nSei vorsichtig!")

	SWEP.PrintName = "golden_deagle_name"
	SWEP.Slot = 6
	SWEP.Icon = "vgui/ttt/icon_golden_deagle"

	-- client side model settings
	SWEP.UseHands = true -- should the hands be displayed
	SWEP.ViewModelFlip = true -- should the weapon be hold with the right or the left hand
	SWEP.ViewModelFOV = 85

	-- Equipment menu information is only needed on the client
	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "golden_deagle_desc"
	}
end

-- always derive from weapon_tttbase
SWEP.Base = "weapon_tttbase"

--[[Default GMod values]]--
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.6
SWEP.Primary.Recoil = 6
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 37
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = 2
SWEP.Primary.DefaultClip = 2
SWEP.Primary.Sound = Sound("Golden_Deagle.Single")

--[[Model settings]]--
SWEP.HoldType = "pistol"
SWEP.ViewModel = Model("models/weapons/zaratusa/golden_deagle/v_golden_deagle.mdl")
SWEP.WorldModel = Model("models/weapons/zaratusa/golden_deagle/w_golden_deagle.mdl")

SWEP.IronSightsPos = Vector(3.76, -0.5, 1.67)
SWEP.IronSightsAng = Vector(-0.6, 0, 0)

--[[TTT config values]]--

-- Kind specifies the category this weapon is in. Players can only carry one of
-- each. Can be: WEAPON_... MELEE, PISTOL, HEAVY, NADE, CARRY, EQUIP1, EQUIP2 or ROLE.
-- Matching SWEP.Slot values: 0      1       2     3      4      6       7        8
SWEP.Kind = WEAPON_EQUIP1

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2,
-- then this gun can be spawned as a random weapon.
SWEP.AutoSpawnable = false

-- The AmmoEnt is the ammo entity that can be picked up when carrying this gun.
SWEP.AmmoEnt = "none"

-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
-- a role is in this table, those players can buy this.
SWEP.CanBuy = {ROLE_DETECTIVE}

-- If LimitedStock is true, you can only buy one per round.
SWEP.LimitedStock = true

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = false

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = false

-- precache sounds
function SWEP:Precache()
	util.PrecacheSound("Golden_Deagle.Single")
end

function SWEP:Initialize()
	if CLIENT and self:Clip1() == -1 then
		self:SetClip1(self.Primary.DefaultClip)
	elseif SERVER then
		self.shotsFired = 0
		self.fingerprints = {}

		self:SetIronsights(false)
	end

	self:SetDeploySpeed(self.DeploySpeed)

	if self.SetHoldType then
		self:SetHoldType(self.HoldType or "pistol")
	end

	PrecacheParticleSystem("smoke_trail")
end

local function GetTeam(ply)
	local role = ply:GetRole()

	if role == ROLE_INNOCENT or role == ROLE_DETECTIVE then
		return 0
	else
		return 1
	end
end

function SWEP:PrimaryAttack()
	if self:CanPrimaryAttack() then
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
		self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

		local owner = self.Owner
		owner:GetViewModel():StopParticles()

		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

		if SERVER then
			sound.Play(self.Primary.Sound, self:GetPos())

			self.shotsFired = self.shotsFired + 1

			local title = "HandleGoldenDeagle" .. self:EntIndex() .. self.shotsFired

			hook.Add("EntityTakeDamage", title, function(ent, dmginfo)
				if IsValid(ent) and ent:IsPlayer() and dmginfo:IsBulletDamage() and dmginfo:GetAttacker():GetActiveWeapon() == self then
					if not TTT2 and (ent.GetTeam and ent:GetTeam() == owner:GetTeam() or not ent.GetTeam and GetTeam(ent) == GetTeam(owner))
					or TTT2 and ent:IsInTeam(owner)
					then
						local newdmg = DamageInfo()
						newdmg:SetDamage(9990)
						newdmg:SetAttacker(owner)
						newdmg:SetInflictor(self)
						newdmg:SetDamageType(DMG_BULLET)
						newdmg:SetDamagePosition(owner:GetPos())

						hook.Remove("EntityTakeDamage", title) -- remove hook before applying new damage

						owner:TakeDamageInfo(newdmg)

						return true -- block all damage on the target
					else
						hook.Remove("EntityTakeDamage", title) -- remove hook before applying new damage

						dmginfo:ScaleDamage(270) -- deals 9990 damage
					end
				else
					hook.Remove("EntityTakeDamage", title)
				end
			end)
		end

		self:ShootBullet(self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self:GetPrimaryCone())
		self:TakePrimaryAmmo(1)

		if IsValid(owner) and not owner:IsNPC() and owner.ViewPunch then
			owner:ViewPunch(Angle(math.Rand(-0.2, -0.1) * self.Primary.Recoil, math.Rand(-0.1, 0.1) * self.Primary.Recoil, 0))
		end

		timer.Simple(0.5, function()
			if IsValid(self) and IsValid(self.Owner) then
				ParticleEffectAttach("smoke_trail", PATTACH_POINT_FOLLOW, self.Owner:GetViewModel(), 1)
			end
		end)
	end
end

function SWEP:Holster()
	if IsValid(self.Owner) then
		local vm = self.Owner:GetViewModel()

		if IsValid(vm) then
			vm:StopParticles()
		end
	end

	return true
end
