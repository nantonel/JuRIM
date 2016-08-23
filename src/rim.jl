"""
Randomized Image Source Method

# Arguments: 

* `Fs::Float64`         : Sampling Frequency 
* `Nt::Int64`           : Time samples
* `xr::Array{Float64}`  : Microphone positions (in meters) (3 by Nm `Array`) where Nm is number of microphones
* `xs::Array{Float64}`  : source positions (in meters) (must be a 3 by 1 `Array`)
* `geo::cuboidRoom`     : object containing dimensions, acoustic properties and random displacement of image sources of the room 


# Optional parameters:

* `c::Float64 = 343.`         : Speed of sound
* `N:Array{Int64,1} = [0;0;0]`: 3 element `Array` representing order of reflection 
                                (set to [0;0;0] to compute full order).
* `Tw::Int64 = 20`            : taps of fractional delay filter
* `Fc::Float64 = 0.9`         : cut-off frequency of fractional delay filter


# Outputs: 
* `h::Array{Float64}`: `h` is a matrix where each column 
		       corresponts to the impulse response of 
		       the microphone positions `xr`
"""

function rim(Fs::Float64,Nt::Int64,
             xr::Array{Float64},xs::Array{Float64},
	     geo::cuboidRoom;
	     c::Float64 = 343.,  N::Array{Int64,1} = [0;0;0], Tw::Int64 = 20,Fc::Float64 = 0.9)
	     
	if(Fs< 0) error("Fs should be positive") end
	if(c< 0)  error("c should be positive") end
	if(size(xr,1)!=3)  error("size(xr,1) must be 3") end
	if(size(xs,1)!=3 || size(xs,2)!=1) error("size(xs,1) must be (3,1)") end
	if(any(N.< 0)) error("N should be positive") end

	L  =  [geo.Lx;geo.Ly;geo.Ly]./c*Fs*2  #convert dimensions to indices
	xr = xr./c*Fs
	xs = xs./c*Fs
	Rd = geo.Rd./c*Fs

	K = size(xr,2)        #number of microphones

	h = zeros(Float64,Nt,K)            # initialize output

	if(N == [0,0,0])
		N = floor(Int64,Nt./L)+1  # compute full order
	end

	for k = 1:K
	
		srand(geo.Sr)
		for u = 0:1, v = 0:1, w = 0:1
			for l = -N[1]:N[1], m = -N[2]:N[2], n = -N[3]:N[3]
	
				# compute distance
				pos_is = [
				xs[1]-2*u*xs[1]+l*L[1]; 
				xs[2]-2*v*xs[2]+m*L[2];
				xs[3]-2*w*xs[3]+n*L[3]
				]                         #position of image source
				
				rand_disp = Rd*(2*rand(3)-1)*norm(sum(abs([u;v;w;l;m;n])),0)
				d = norm(pos_is+rand_disp-xr[:,k])+1

				# when norm(sum(abs( [u,v,w,l,m,n])),0) == 0 
				# we have direct path, so
				# no displacement is added
	
				# instead of moving the source on a line
				# as in the paper, we are moving the source 
				# in a cube with 2*Rd edge

				if(round(Int64,d)>Nt || round(Int64,d)<1)
					#if index not exceed length h
					continue
				end

				if(Tw == 0)
					indx = round(Int64,d) #calculate index  
					s = 1
				else
					indx = (
				maximum([ceil(Int64,d-Tw/2),1]):minimum([floor(Int64,d+Tw/2),Nt])
				               )
					# create time window
					s = (1+cos(2*π*(indx-d)/Tw)).*sinc(Fc*(indx-d))/2
					# compute filtered impulse
				end
	
				A = prod(geo.β.^abs([l-u,l,m-v,m,n-w,n]))/(4*π*(d-1))
				h[indx,k] = h[indx,k] + s.*A
			end
		end
	end

return h.*(Fs/c)

end
